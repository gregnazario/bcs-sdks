import 'dart:convert';
import 'dart:typed_data';
import 'constants.dart';
import 'errors.dart';
import 'uleb128.dart';

/// BCS Serializer - Manual serialization API
class BcsSerializer {
  /// Internal buffer with dynamic growth
  Uint8List _buffer;
  int _size = 0;
  int _depth = 0;

  /// Scratch buffer for ULEB128 encoding
  final Uint8List _ulebBuffer = Uint8List(Uleb128.maxBytes);

  /// Create a serializer with optional initial capacity
  BcsSerializer([int initialCapacity = 256])
      : _buffer = Uint8List(initialCapacity);

  /// Ensure buffer has capacity for [needed] more bytes
  void _ensureCapacity(int needed) {
    final required = _size + needed;
    if (required <= _buffer.length) return;

    // Grow by doubling or to required size, whichever is larger
    var newCapacity = _buffer.length * 2;
    if (newCapacity < required) newCapacity = required;
    final newBuffer = Uint8List(newCapacity);
    newBuffer.setRange(0, _size, _buffer);
    _buffer = newBuffer;
  }

  // ==========================================================================
  // BOOLEAN
  // ==========================================================================

  /// Write a boolean value
  BcsSerializer writeBool(bool value) {
    _ensureCapacity(1);
    _buffer[_size++] = value ? 1 : 0;
    return this;
  }

  // ==========================================================================
  // UNSIGNED INTEGERS
  // ==========================================================================

  /// Write an unsigned 8-bit integer
  BcsSerializer writeU8(int value) {
    if (value < 0 || value > u8Max) {
      throw BcsError.integerOutOfRange('u8');
    }
    _ensureCapacity(1);
    _buffer[_size++] = value;
    return this;
  }

  /// Write an unsigned 16-bit integer (little-endian)
  BcsSerializer writeU16(int value) {
    if (value < 0 || value > u16Max) {
      throw BcsError.integerOutOfRange('u16');
    }
    _ensureCapacity(2);
    _buffer[_size] = value & 0xFF;
    _buffer[_size + 1] = (value >> 8) & 0xFF;
    _size += 2;
    return this;
  }

  /// Write an unsigned 32-bit integer (little-endian)
  BcsSerializer writeU32(int value) {
    if (value < 0 || value > u32Max) {
      throw BcsError.integerOutOfRange('u32');
    }
    _ensureCapacity(4);
    // Unrolled for performance
    _buffer[_size] = value & 0xFF;
    _buffer[_size + 1] = (value >> 8) & 0xFF;
    _buffer[_size + 2] = (value >> 16) & 0xFF;
    _buffer[_size + 3] = (value >> 24) & 0xFF;
    _size += 4;
    return this;
  }

  /// Write an unsigned 64-bit integer (little-endian)
  BcsSerializer writeU64(BigInt value) {
    if (value < BigInt.zero || value > u64Max) {
      throw BcsError.integerOutOfRange('u64');
    }
    _writeBigIntLE(value, 8);
    return this;
  }

  /// Write an unsigned 64-bit integer from int (little-endian)
  BcsSerializer writeU64Int(int value) {
    // Optimize: write int directly for small values
    if (value >= 0) {
      _ensureCapacity(8);
      _buffer[_size] = value & 0xFF;
      _buffer[_size + 1] = (value >> 8) & 0xFF;
      _buffer[_size + 2] = (value >> 16) & 0xFF;
      _buffer[_size + 3] = (value >> 24) & 0xFF;
      _buffer[_size + 4] = (value >> 32) & 0xFF;
      _buffer[_size + 5] = (value >> 40) & 0xFF;
      _buffer[_size + 6] = (value >> 48) & 0xFF;
      _buffer[_size + 7] = (value >> 56) & 0xFF;
      _size += 8;
      return this;
    }
    return writeU64(BigInt.from(value));
  }

  /// Write an unsigned 128-bit integer (little-endian)
  BcsSerializer writeU128(BigInt value) {
    if (value < BigInt.zero || value > u128Max) {
      throw BcsError.integerOutOfRange('u128');
    }
    _writeBigIntLE(value, 16);
    return this;
  }

  /// Write an unsigned 256-bit integer (little-endian)
  BcsSerializer writeU256(BigInt value) {
    if (value < BigInt.zero || value > u256Max) {
      throw BcsError.integerOutOfRange('u256');
    }
    _writeBigIntLE(value, 32);
    return this;
  }

  // ==========================================================================
  // SIGNED INTEGERS
  // ==========================================================================

  /// Write a signed 8-bit integer
  BcsSerializer writeI8(int value) {
    if (value < i8Min || value > i8Max) {
      throw BcsError.integerOutOfRange('i8');
    }
    _ensureCapacity(1);
    _buffer[_size++] = value & 0xFF;
    return this;
  }

  /// Write a signed 16-bit integer (little-endian)
  BcsSerializer writeI16(int value) {
    if (value < i16Min || value > i16Max) {
      throw BcsError.integerOutOfRange('i16');
    }
    final unsigned = value & 0xFFFF;
    _ensureCapacity(2);
    _buffer[_size] = unsigned & 0xFF;
    _buffer[_size + 1] = (unsigned >> 8) & 0xFF;
    _size += 2;
    return this;
  }

  /// Write a signed 32-bit integer (little-endian)
  BcsSerializer writeI32(int value) {
    if (value < i32Min || value > i32Max) {
      throw BcsError.integerOutOfRange('i32');
    }
    final unsigned = value & 0xFFFFFFFF;
    _ensureCapacity(4);
    _buffer[_size] = unsigned & 0xFF;
    _buffer[_size + 1] = (unsigned >> 8) & 0xFF;
    _buffer[_size + 2] = (unsigned >> 16) & 0xFF;
    _buffer[_size + 3] = (unsigned >> 24) & 0xFF;
    _size += 4;
    return this;
  }

  /// Write a signed 64-bit integer (little-endian)
  BcsSerializer writeI64(BigInt value) {
    if (value < i64Min || value > i64Max) {
      throw BcsError.integerOutOfRange('i64');
    }
    _writeSignedBigIntLE(value, 8);
    return this;
  }

  /// Write a signed 128-bit integer (little-endian)
  BcsSerializer writeI128(BigInt value) {
    if (value < i128Min || value > i128Max) {
      throw BcsError.integerOutOfRange('i128');
    }
    _writeSignedBigIntLE(value, 16);
    return this;
  }

  /// Write a signed 256-bit integer (little-endian)
  BcsSerializer writeI256(BigInt value) {
    if (value < i256Min || value > i256Max) {
      throw BcsError.integerOutOfRange('i256');
    }
    _writeSignedBigIntLE(value, 32);
    return this;
  }

  // ==========================================================================
  // ULEB128
  // ==========================================================================

  /// Write a ULEB128-encoded length
  BcsSerializer writeUleb128(int value) {
    // Fast path for small values (0-127)
    if (value < 0x80) {
      _ensureCapacity(1);
      _buffer[_size++] = value;
      return this;
    }
    // Use scratch buffer for larger values
    final len = Uleb128.encodeInto(value, _ulebBuffer);
    _ensureCapacity(len);
    _buffer.setRange(_size, _size + len, _ulebBuffer);
    _size += len;
    return this;
  }

  // ==========================================================================
  // BYTES AND STRINGS
  // ==========================================================================

  /// Write fixed-length bytes (without length prefix)
  BcsSerializer writeFixedBytes(Uint8List data) {
    final len = data.length;
    _ensureCapacity(len);
    _buffer.setRange(_size, _size + len, data);
    _size += len;
    return this;
  }

  /// Write bytes with ULEB128 length prefix
  BcsSerializer writeBytes(Uint8List data) {
    _checkSequenceLength(data.length);
    // Pre-calculate total size needed
    final ulebSize = Uleb128.encodedSize(data.length);
    _ensureCapacity(ulebSize + data.length);
    writeUleb128(data.length);
    _buffer.setRange(_size, _size + data.length, data);
    _size += data.length;
    return this;
  }

  /// Write a UTF-8 string with ULEB128 length prefix
  BcsSerializer writeString(String value) {
    final bytes = utf8.encode(value);
    _checkSequenceLength(bytes.length);
    final ulebSize = Uleb128.encodedSize(bytes.length);
    _ensureCapacity(ulebSize + bytes.length);
    writeUleb128(bytes.length);
    _buffer.setRange(_size, _size + bytes.length, bytes);
    _size += bytes.length;
    return this;
  }

  // ==========================================================================
  // COMPOSITE TYPES
  // ==========================================================================

  /// Write an optional value
  BcsSerializer writeOption<T>(
    T? value,
    void Function(BcsSerializer, T) serializer,
  ) {
    if (value == null) {
      _ensureCapacity(1);
      _buffer[_size++] = 0;
    } else {
      _ensureCapacity(1);
      _buffer[_size++] = 1;
      serializer(this, value);
    }
    return this;
  }

  /// Write a vector with element serializer
  BcsSerializer writeVector<T>(
    List<T> values,
    void Function(BcsSerializer, T) serializer,
  ) {
    _checkSequenceLength(values.length);
    writeUleb128(values.length);
    for (final value in values) {
      serializer(this, value);
    }
    return this;
  }

  /// Write a map with key/value serializers (sorted by serialized key bytes)
  BcsSerializer writeMap<K, V>(
    Map<K, V> map,
    void Function(BcsSerializer, K) keySerializer,
    void Function(BcsSerializer, V) valueSerializer,
  ) {
    _checkSequenceLength(map.length);

    // Serialize all keys to get their byte representation
    final entries = <(Uint8List, K, V)>[];
    for (final entry in map.entries) {
      final keySer = BcsSerializer();
      keySerializer(keySer, entry.key);
      entries.add((keySer.toBytes(), entry.key, entry.value));
    }

    // Sort by key bytes (lexicographic)
    entries.sort((a, b) => _compareBytes(a.$1, b.$1));

    // Write length and entries
    writeUleb128(entries.length);
    for (final (keyBytes, _, value) in entries) {
      writeFixedBytes(keyBytes);
      valueSerializer(this, value);
    }

    return this;
  }

  /// Write an enum variant index (ULEB128)
  BcsSerializer writeVariantIndex(int index) {
    _enterContainer();
    writeUleb128(index);
    return this;
  }

  // ==========================================================================
  // CONTAINER DEPTH
  // ==========================================================================

  /// Enter a struct container for depth tracking
  BcsSerializer enterStruct([String name = '']) {
    _enterContainer();
    return this;
  }

  /// Leave the current struct container
  BcsSerializer leaveStruct() {
    _leaveContainer();
    return this;
  }

  /// Enter an enum container and write variant index
  BcsSerializer enterEnum(int index) {
    return writeVariantIndex(index);
  }

  /// Leave the current enum container
  BcsSerializer leaveEnum() {
    _leaveContainer();
    return this;
  }

  // ==========================================================================
  // OUTPUT
  // ==========================================================================

  /// Get the serialized bytes
  Uint8List toBytes() {
    return Uint8List.sublistView(_buffer, 0, _size);
  }

  /// Get the current size of the buffer
  int get size => _size;

  /// Clear the buffer
  void clear() {
    _size = 0;
    _depth = 0;
  }

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

  /// Optimized BigInt write using direct byte extraction
  void _writeBigIntLE(BigInt value, int byteLength) {
    _ensureCapacity(byteLength);
    final mask = BigInt.from(0xFF);
    var v = value;
    for (var i = 0; i < byteLength; i++) {
      _buffer[_size + i] = (v & mask).toInt();
      v >>= 8;
    }
    _size += byteLength;
  }

  void _writeSignedBigIntLE(BigInt value, int byteLength) {
    final mask = (BigInt.one << (byteLength * 8)) - BigInt.one;
    final unsigned = value & mask;
    _writeBigIntLE(unsigned, byteLength);
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
