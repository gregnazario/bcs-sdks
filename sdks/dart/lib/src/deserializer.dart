import 'dart:convert';
import 'dart:typed_data';
import 'constants.dart';
import 'errors.dart';
import 'uleb128.dart';

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
    final byte = readU8();
    switch (byte) {
      case 0:
        return false;
      case 1:
        return true;
      default:
        throw BcsError.invalidBoolean(byte);
    }
  }

  // ==========================================================================
  // UNSIGNED INTEGERS
  // ==========================================================================

  /// Read an unsigned 8-bit integer
  int readU8() {
    _checkRemaining(1);
    return _data[_offset++];
  }

  /// Read an unsigned 16-bit integer (little-endian)
  int readU16() {
    _checkRemaining(2);
    final value = _data[_offset] | (_data[_offset + 1] << 8);
    _offset += 2;
    return value;
  }

  /// Read an unsigned 32-bit integer (little-endian)
  int readU32() {
    _checkRemaining(4);
    var value = 0;
    for (var i = 0; i < 4; i++) {
      value |= _data[_offset + i] << (i * 8);
    }
    _offset += 4;
    return value;
  }

  /// Read an unsigned 64-bit integer (little-endian)
  BigInt readU64() {
    _checkRemaining(8);
    final value = _readBigIntLE(8);
    return value;
  }

  /// Read an unsigned 128-bit integer (little-endian)
  BigInt readU128() {
    _checkRemaining(16);
    return _readBigIntLE(16);
  }

  /// Read an unsigned 256-bit integer (little-endian)
  BigInt readU256() {
    _checkRemaining(32);
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
    final signBit = BigInt.one << 63;
    if (value >= signBit) {
      return value - (BigInt.one << 64);
    }
    return value;
  }

  /// Read a signed 128-bit integer (little-endian)
  BigInt readI128() {
    final value = readU128();
    final signBit = BigInt.one << 127;
    if (value >= signBit) {
      return value - (BigInt.one << 128);
    }
    return value;
  }

  /// Read a signed 256-bit integer (little-endian)
  BigInt readI256() {
    final value = readU256();
    final signBit = BigInt.one << 255;
    if (value >= signBit) {
      return value - (BigInt.one << 256);
    }
    return value;
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

  /// Read fixed-length bytes (without length prefix)
  Uint8List readFixedBytes(int length) {
    _checkRemaining(length);
    final result = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return result;
  }

  /// Read bytes with ULEB128 length prefix
  Uint8List readBytes() {
    final length = readUleb128();
    _checkSequenceLength(length);
    return readFixedBytes(length);
  }

  /// Read a UTF-8 string with ULEB128 length prefix
  String readString() {
    final bytes = readBytes();
    try {
      return utf8.decode(bytes, allowMalformed: false);
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
    return List.generate(length, (_) => deserializer(this));
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

      // Get key bytes for ordering check
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
      prevKeyBytes = keyBytes;

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

  void _checkRemaining(int needed) {
    if (_offset + needed > _data.length) {
      throw BcsError.unexpectedEof();
    }
  }

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

  BigInt _readBigIntLE(int byteLength) {
    var value = BigInt.zero;
    for (var i = 0; i < byteLength; i++) {
      value |= BigInt.from(_data[_offset + i]) << (i * 8);
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
