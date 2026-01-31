import 'dart:convert';
import 'dart:typed_data';
import 'constants.dart';
import 'errors.dart';
import 'uleb128.dart';

/// Cached constants for signed integer conversion
final BigInt _signBit64 = BigInt.one << 63;
final BigInt _signBit128 = BigInt.one << 127;
final BigInt _signBit256 = BigInt.one << 255;
final BigInt _mask64 = BigInt.one << 64;
final BigInt _mask128 = BigInt.one << 128;
final BigInt _mask256 = BigInt.one << 256;

/// BCS Deserializer - Manual deserialization API
class BcsDeserializer {
  /// Creates a deserializer from a Uint8List.
  BcsDeserializer(Uint8List data) : _data = data;

  /// Create from a list of integers
  factory BcsDeserializer.fromList(List<int> data) {
    return BcsDeserializer(Uint8List.fromList(data));
  }

  final Uint8List _data;
  int _offset = 0;
  int _depth = 0;

  // ==========================================================================
  // BOOLEAN
  // ==========================================================================

  /// Read a boolean value
  bool readBool() {
    if (_offset >= _data.length) {
      throw BcsError.unexpectedEof();
    }
    final byte = _data[_offset++];
    if (byte == 0) return false;
    if (byte == 1) return true;
    throw BcsError.invalidBoolean(byte);
  }

  // ==========================================================================
  // UNSIGNED INTEGERS
  // ==========================================================================

  /// Read an unsigned 8-bit integer
  int readU8() {
    if (_offset >= _data.length) {
      throw BcsError.unexpectedEof();
    }
    return _data[_offset++];
  }

  /// Read an unsigned 16-bit integer (little-endian)
  int readU16() {
    if (_offset + 2 > _data.length) {
      throw BcsError.unexpectedEof();
    }
    final value = _data[_offset] | (_data[_offset + 1] << 8);
    _offset += 2;
    return value;
  }

  /// Read an unsigned 32-bit integer (little-endian)
  int readU32() {
    if (_offset + 4 > _data.length) {
      throw BcsError.unexpectedEof();
    }
    // Unrolled for performance
    final value = _data[_offset] |
        (_data[_offset + 1] << 8) |
        (_data[_offset + 2] << 16) |
        (_data[_offset + 3] << 24);
    _offset += 4;
    return value;
  }

  /// Read an unsigned 64-bit integer (little-endian) as [BigInt].
  ///
  /// For values known to fit in a native [int], consider using [readU64Int]
  /// for better performance.
  BigInt readU64() {
    if (_offset + 8 > _data.length) {
      throw BcsError.unexpectedEof();
    }
    return _readBigIntLE(8);
  }

  /// Read an unsigned 64-bit integer (little-endian) as native [int].
  ///
  /// This is an optimized version of [readU64] that returns a native [int].
  /// On the Dart VM, this supports the full u64 range. On Dart Web (JavaScript),
  /// values larger than 2^53-1 may lose precision.
  ///
  /// For values that require full 64-bit precision on all platforms,
  /// use [readU64] which returns [BigInt].
  int readU64Int() {
    if (_offset + 8 > _data.length) {
      throw BcsError.unexpectedEof();
    }
    // Read directly as int for better performance
    final value = _data[_offset] |
        (_data[_offset + 1] << 8) |
        (_data[_offset + 2] << 16) |
        (_data[_offset + 3] << 24) |
        (_data[_offset + 4] << 32) |
        (_data[_offset + 5] << 40) |
        (_data[_offset + 6] << 48) |
        (_data[_offset + 7] << 56);
    _offset += 8;
    return value;
  }

  /// Read an unsigned 128-bit integer (little-endian)
  BigInt readU128() {
    if (_offset + 16 > _data.length) {
      throw BcsError.unexpectedEof();
    }
    return _readBigIntLE(16);
  }

  /// Read an unsigned 256-bit integer (little-endian)
  BigInt readU256() {
    if (_offset + 32 > _data.length) {
      throw BcsError.unexpectedEof();
    }
    return _readBigIntLE(32);
  }

  // ==========================================================================
  // SIGNED INTEGERS
  // ==========================================================================

  /// Read a signed 8-bit integer
  int readI8() {
    final value = readU8();
    return value >= 0x80 ? value - 0x100 : value;
  }

  /// Read a signed 16-bit integer (little-endian)
  int readI16() {
    final value = readU16();
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  /// Read a signed 32-bit integer (little-endian)
  int readI32() {
    final value = readU32();
    return value >= 0x80000000 ? value - 0x100000000 : value;
  }

  /// Read a signed 64-bit integer (little-endian)
  BigInt readI64() {
    final value = readU64();
    return value >= _signBit64 ? value - _mask64 : value;
  }

  /// Read a signed 128-bit integer (little-endian)
  BigInt readI128() {
    final value = readU128();
    return value >= _signBit128 ? value - _mask128 : value;
  }

  /// Read a signed 256-bit integer (little-endian)
  BigInt readI256() {
    final value = readU256();
    return value >= _signBit256 ? value - _mask256 : value;
  }

  // ==========================================================================
  // ULEB128
  // ==========================================================================

  /// Read a ULEB128-encoded value
  int readUleb128() {
    final result = Uleb128.decode(_data, _offset);
    _offset += result.bytesRead;
    return result.value;
  }

  // ==========================================================================
  // BYTES AND STRINGS
  // ==========================================================================

  /// Read fixed-length bytes (without length prefix) as a copy.
  ///
  /// Returns a new [Uint8List] containing a copy of the bytes.
  /// This is safe to modify without affecting the deserializer.
  ///
  /// For performance-critical code where you don't need to modify the bytes,
  /// consider using [readFixedBytesView] instead.
  Uint8List readFixedBytes(int length) {
    if (_offset + length > _data.length) {
      throw BcsError.unexpectedEof();
    }
    final result = Uint8List.fromList(_data.sublist(_offset, _offset + length));
    _offset += length;
    return result;
  }

  /// Read fixed-length bytes (without length prefix) as a view (zero-copy).
  ///
  /// **WARNING:** The returned [Uint8List] is a view into the input buffer.
  /// Modifying the returned bytes will modify the original input data.
  /// Only use this when you need maximum performance and won't modify the result.
  Uint8List readFixedBytesView(int length) {
    if (_offset + length > _data.length) {
      throw BcsError.unexpectedEof();
    }
    final result = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return result;
  }

  /// Read bytes with ULEB128 length prefix as a copy.
  ///
  /// Returns a new [Uint8List] containing a copy of the bytes.
  Uint8List readBytes() {
    final length = readUleb128();
    _checkSequenceLength(length);
    return readFixedBytes(length);
  }

  /// Read bytes with ULEB128 length prefix as a view (zero-copy).
  ///
  /// **WARNING:** The returned [Uint8List] is a view into the input buffer.
  Uint8List readBytesView() {
    final length = readUleb128();
    _checkSequenceLength(length);
    return readFixedBytesView(length);
  }

  /// Read a UTF-8 string with ULEB128 length prefix
  String readString() {
    final length = readUleb128();
    _checkSequenceLength(length);
    if (_offset + length > _data.length) {
      throw BcsError.unexpectedEof();
    }
    // Decode directly from view to avoid copy (utf8.decode doesn't modify input)
    try {
      final str = utf8.decode(
        Uint8List.sublistView(_data, _offset, _offset + length),
        allowMalformed: false,
      );
      _offset += length;
      return str;
    } on FormatException {
      throw BcsError.invalidUtf8();
    }
  }

  // ==========================================================================
  // COMPOSITE TYPES
  // ==========================================================================

  /// Read an optional value
  T? readOption<T>(T Function(BcsDeserializer) deserializer) {
    final tag = readU8();
    switch (tag) {
      case 0:
        return null;
      case 1:
        return deserializer(this);
      default:
        throw BcsError.invalidOption(tag);
    }
  }

  /// Read a vector with element deserializer
  List<T> readVector<T>(T Function(BcsDeserializer) deserializer) {
    final length = readUleb128();
    _checkSequenceLength(length);
    // Pre-allocate list with known size for better performance
    final result = List<T>.filled(length, null as T);
    for (var i = 0; i < length; i++) {
      result[i] = deserializer(this);
    }
    return result;
  }

  /// Read a map with key/value deserializers
  Map<K, V> readMap<K, V>(
    K Function(BcsDeserializer) keyDeserializer,
    V Function(BcsDeserializer) valueDeserializer,
  ) {
    final length = readUleb128();
    _checkSequenceLength(length);

    final result = <K, V>{};
    Uint8List? prevKeyBytes;

    for (var i = 0; i < length; i++) {
      // Record start position to get key bytes
      final keyStart = _offset;

      final key = keyDeserializer(this);

      // Get key bytes for ordering check (use view - we only compare, don't modify)
      final keyBytes = Uint8List.sublistView(_data, keyStart, _offset);

      // Check ordering
      if (prevKeyBytes != null) {
        final cmp = _compareBytes(keyBytes, prevKeyBytes);
        if (cmp <= 0) {
          if (cmp == 0) {
            throw BcsError.duplicateMapKey();
          }
          throw BcsError.nonCanonicalMap();
        }
      }
      // Store a copy for the next comparison since we'll reuse the view
      prevKeyBytes = Uint8List.fromList(keyBytes);

      final value = valueDeserializer(this);
      result[key] = value;
    }

    return result;
  }

  /// Read an enum variant index (ULEB128)
  int readVariantIndex() {
    _enterContainer();
    return readUleb128();
  }

  // ==========================================================================
  // CONTAINER DEPTH
  // ==========================================================================

  /// Enter a struct container for depth tracking
  BcsDeserializer enterStruct([String name = '']) {
    _enterContainer();
    return this;
  }

  /// Leave the current struct container
  BcsDeserializer leaveStruct() {
    _leaveContainer();
    return this;
  }

  /// Enter an enum container and read variant index
  int enterEnum() {
    return readVariantIndex();
  }

  /// Leave the current enum container
  BcsDeserializer leaveEnum() {
    _leaveContainer();
    return this;
  }

  // ==========================================================================
  // STATE
  // ==========================================================================

  /// Check that all input has been consumed
  void checkEnd() {
    if (_offset < _data.length) {
      throw BcsError.remainingInput(_data.length - _offset);
    }
  }

  /// Get the current offset
  int get offset => _offset;

  /// Get the remaining bytes count
  int get remaining => _data.length - _offset;

  /// Check if there's more data to read
  bool get hasRemaining => _offset < _data.length;

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  void _checkSequenceLength(int length) {
    if (length > maxSequenceLength) {
      throw BcsError.exceededMaxLength(length, maxSequenceLength);
    }
  }

  void _enterContainer() {
    _depth++;
    if (_depth > maxContainerDepth) {
      throw BcsError.exceededContainerDepth(_depth, maxContainerDepth);
    }
  }

  void _leaveContainer() {
    if (_depth > 0) {
      _depth--;
    }
  }

  /// Optimized BigInt read - builds value from bytes.
  ///
  /// Uses 64-bit chunks for better performance with large integers (u128, u256).
  /// This reduces the number of BigInt operations from O(n) to O(n/8).
  BigInt _readBigIntLE(int byteLength) {
    var value = BigInt.zero;

    // Process in 64-bit chunks for better performance
    final fullChunks = byteLength ~/ 8;
    final remainingBytes = byteLength % 8;

    // Process full 64-bit chunks from most significant to least significant
    for (var chunk = fullChunks - 1; chunk >= 0; chunk--) {
      final chunkOffset = _offset + chunk * 8;
      // Build 64-bit word from little-endian bytes
      final word = _data[chunkOffset] |
          (_data[chunkOffset + 1] << 8) |
          (_data[chunkOffset + 2] << 16) |
          (_data[chunkOffset + 3] << 24) |
          (_data[chunkOffset + 4] << 32) |
          (_data[chunkOffset + 5] << 40) |
          (_data[chunkOffset + 6] << 48) |
          (_data[chunkOffset + 7] << 56);

      if (value == BigInt.zero) {
        value = BigInt.from(word).toUnsigned(64);
      } else {
        value = (value << 64) | BigInt.from(word).toUnsigned(64);
      }
    }

    // Handle any remaining bytes (for non-8-byte-aligned lengths)
    if (remainingBytes > 0) {
      final remainingOffset = _offset + fullChunks * 8;
      var remaining = 0;
      for (var i = remainingBytes - 1; i >= 0; i--) {
        remaining = (remaining << 8) | _data[remainingOffset + i];
      }
      if (value == BigInt.zero) {
        value = BigInt.from(remaining);
      } else {
        value = (value << (remainingBytes * 8)) | BigInt.from(remaining);
      }
    }

    _offset += byteLength;
    return value;
  }

  static int _compareBytes(Uint8List a, Uint8List b) {
    final minLen = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < minLen; i++) {
      if (a[i] < b[i]) return -1;
      if (a[i] > b[i]) return 1;
    }
    return a.length.compareTo(b.length);
  }
}
