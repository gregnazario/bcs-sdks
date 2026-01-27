import 'dart:typed_data';
import 'errors.dart';

/// ULEB128 encoding/decoding utilities
class Uleb128 {
  /// Maximum value that can be encoded as ULEB128 in BCS (u32 max)
  static const int maxValue = 0xFFFFFFFF;

  /// Maximum number of bytes in a ULEB128-encoded u32
  static const int maxBytes = 5;

  /// Encode a 32-bit unsigned integer as ULEB128
  static Uint8List encode(int value) {
    if (value < 0 || value > maxValue) {
      throw BcsError.integerOutOfRange('uleb128');
    }

    final result = <int>[];
    var v = value;

    do {
      var byte = v & 0x7F;
      v >>= 7;
      if (v != 0) {
        byte |= 0x80;
      }
      result.add(byte);
    } while (v != 0);

    return Uint8List.fromList(result);
  }

  /// Decode a ULEB128-encoded value from bytes
  /// Returns a record with the decoded value and number of bytes consumed
  static ({int value, int bytesRead}) decode(Uint8List data, [int offset = 0]) {
    var value = 0;
    var shift = 0;
    var bytesRead = 0;

    for (var i = 0; i < maxBytes; i++) {
      if (offset + i >= data.length) {
        throw BcsError.unexpectedEof();
      }

      final byte = data[offset + i];
      final digit = byte & 0x7F;

      value |= digit << shift;
      bytesRead = i + 1;

      // Check if this is the last byte (high bit not set)
      if ((byte & 0x80) == 0) {
        // Check for non-canonical encoding (trailing zeros)
        if (shift > 0 && digit == 0) {
          throw BcsError.nonCanonicalUleb128();
        }

        // Check for overflow
        if (value > maxValue) {
          throw BcsError.uleb128Overflow();
        }

        return (value: value, bytesRead: bytesRead);
      }

      shift += 7;
    }

    // If we've read maxBytes and still have continuation bit, overflow
    throw BcsError.uleb128Overflow();
  }

  /// Calculate the encoded size of a value
  static int encodedSize(int value) {
    var size = 1;
    var v = value;
    while (v >= 0x80) {
      v >>= 7;
      size++;
    }
    return size;
  }
}
