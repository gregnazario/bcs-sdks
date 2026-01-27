import 'dart:typed_data';
import 'errors.dart';

/// ULEB128 encoding/decoding utilities
class Uleb128 {
  /// Maximum value that can be encoded as ULEB128 in BCS (u32 max)
  static const int maxValue = 0xFFFFFFFF;

  /// Maximum number of bytes in a ULEB128-encoded u32
  static const int maxBytes = 5;

  /// Pre-allocated buffer for encoding (avoid allocation in hot path)
  static final Uint8List _encodeBuffer = Uint8List(maxBytes);

  /// Encode a 32-bit unsigned integer as ULEB128 into a pre-allocated buffer
  /// Returns the number of bytes written
  static int encodeInto(int value, Uint8List buffer, [int offset = 0]) {
    if (value < 0 || value > maxValue) {
      throw BcsError.integerOutOfRange('uleb128');
    }

    var v = value;
    var i = offset;

    do {
      var byte = v & 0x7F;
      v >>= 7;
      if (v != 0) {
        byte |= 0x80;
      }
      buffer[i++] = byte;
    } while (v != 0);

    return i - offset;
  }

  /// Encode a 32-bit unsigned integer as ULEB128
  static Uint8List encode(int value) {
    final len = encodeInto(value, _encodeBuffer);
    return Uint8List.fromList(_encodeBuffer.sublist(0, len));
  }

  /// Decode a ULEB128-encoded value from bytes
  /// Returns a record with the decoded value and number of bytes consumed
  static ({int value, int bytesRead}) decode(Uint8List data, [int offset = 0]) {
    final remaining = data.length - offset;
    if (remaining == 0) {
      throw BcsError.unexpectedEof();
    }

    // Fast path: single byte (values 0-127, very common for lengths)
    final firstByte = data[offset];
    if ((firstByte & 0x80) == 0) {
      return (value: firstByte, bytesRead: 1);
    }

    // Multi-byte path
    var value = firstByte & 0x7F;
    var shift = 7;
    final maxIter = remaining < maxBytes ? remaining : maxBytes;

    for (var i = 1; i < maxIter; i++) {
      final byte = data[offset + i];
      final digit = byte & 0x7F;

      value |= digit << shift;

      if ((byte & 0x80) == 0) {
        // Check for non-canonical encoding (trailing zeros)
        if (digit == 0) {
          throw BcsError.nonCanonicalUleb128();
        }
        // Check for overflow
        if (value > maxValue) {
          throw BcsError.uleb128Overflow();
        }
        return (value: value, bytesRead: i + 1);
      }
      shift += 7;
    }

    if (maxIter == maxBytes) {
      throw BcsError.uleb128Overflow();
    }
    throw BcsError.unexpectedEof();
  }

  /// Calculate the encoded size of a value (optimized with bit comparisons)
  static int encodedSize(int value) {
    if (value < (1 << 7)) return 1;
    if (value < (1 << 14)) return 2;
    if (value < (1 << 21)) return 3;
    if (value < (1 << 28)) return 4;
    return 5;
  }
}
