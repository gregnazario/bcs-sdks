package com.bcs;

/**
 * ULEB128 encoding and decoding for BCS.
 *
 * <p>ULEB128 (Unsigned Little-Endian Base 128) is a variable-length encoding for unsigned integers.
 * Each byte contributes 7 bits of data, with the high bit indicating whether more bytes follow.</p>
 */
public final class Uleb128 {

  /** Maximum value that can be encoded (u32 max). */
  public static final long MAX_U32 = 0xFFFFFFFFL;

  private Uleb128() {
    // Utility class
  }

  /**
   * Encode an unsigned integer as ULEB128.
   *
   * @param value the value to encode (must be 0 <= value <= 2^32-1)
   * @return the ULEB128 encoded bytes
   * @throws IllegalArgumentException if value is negative or exceeds u32 max
   */
  public static byte[] encode(long value) {
    if (value < 0) {
      throw new IllegalArgumentException("ULEB128 cannot encode negative values: " + value);
    }
    if (value > MAX_U32) {
      throw new IllegalArgumentException("ULEB128 value exceeds u32 max: " + value);
    }

    // Fast path for small values (most common case)
    if (value < 0x80) {
      return new byte[] {(byte) value};
    }
    if (value < 0x4000) {
      return new byte[] {(byte) ((value & 0x7F) | 0x80), (byte) (value >>> 7)};
    }

    // General case: use fixed-size array (max 5 bytes for u32)
    byte[] buf = new byte[5];
    int len = 0;
    long remaining = value;

    do {
      int byteVal = (int) (remaining & 0x7F);
      remaining >>>= 7;
      if (remaining != 0) {
        byteVal |= 0x80;
      }
      buf[len++] = (byte) byteVal;
    } while (remaining != 0);

    // Return exact-sized array
    if (len == 5) {
      return buf;
    }
    byte[] result = new byte[len];
    System.arraycopy(buf, 0, result, 0, len);
    return result;
  }

  /**
   * Encode a ULEB128 value directly into a byte array.
   *
   * @param value the value to encode
   * @param dest the destination array
   * @param offset the offset to write at
   * @return the number of bytes written
   */
  public static int encodeTo(long value, byte[] dest, int offset) {
    if (value < 0 || value > MAX_U32) {
      throw new IllegalArgumentException("ULEB128 value out of range: " + value);
    }

    int pos = offset;
    long remaining = value;

    do {
      int byteVal = (int) (remaining & 0x7F);
      remaining >>>= 7;
      if (remaining != 0) {
        byteVal |= 0x80;
      }
      dest[pos++] = (byte) byteVal;
    } while (remaining != 0);

    return pos - offset;
  }

  /**
   * Decode a ULEB128 value from a byte array.
   *
   * @param data the data to decode from
   * @param offset the offset to start decoding from
   * @return a DecodeResult containing the decoded value and bytes consumed
   * @throws BcsError if decoding fails
   */
  public static DecodeResult decode(byte[] data, int offset) {
    long value = 0;
    int shift = 0;
    int bytesRead = 0;

    while (true) {
      if (offset + bytesRead >= data.length) {
        throw BcsError.unexpectedEof();
      }

      int byteVal = data[offset + bytesRead] & 0xFF;
      bytesRead++;

      // Check for overflow before adding (5 bytes max for u32)
      if (bytesRead == 5) {
        // Check for non-canonical encoding (could have been encoded in 4 bytes)
        if (byteVal == 0) {
          throw BcsError.nonCanonicalUleb128();
        }
        if (byteVal >= 0x10) {
          throw BcsError.uleb128Overflow();
        }
        // Final byte for 5-byte encoding
        value |= ((long) byteVal) << shift;
        if (value > MAX_U32) {
          throw BcsError.uleb128Overflow();
        }
        return new DecodeResult(value, bytesRead);
      }

      int digit = byteVal & 0x7F;
      value |= ((long) digit) << shift;

      if ((byteVal & 0x80) == 0) {
        // Last byte - check for non-canonical encoding
        if (bytesRead > 1 && byteVal == 0) {
          throw BcsError.nonCanonicalUleb128();
        }
        return new DecodeResult(value, bytesRead);
      }

      shift += 7;
    }
  }

  /**
   * Calculate the number of bytes needed to encode a value.
   *
   * @param value the value to measure
   * @return the number of bytes needed
   */
  public static int encodedSize(long value) {
    if (value == 0) {
      return 1;
    }

    int size = 0;
    long remaining = value;
    while (remaining > 0) {
      remaining >>>= 7;
      size++;
    }
    return size;
  }

  /** Result of ULEB128 decoding. */
  public static class DecodeResult {
    private final long value;
    private final int bytesConsumed;

    public DecodeResult(long value, int bytesConsumed) {
      this.value = value;
      this.bytesConsumed = bytesConsumed;
    }

    public long getValue() {
      return value;
    }

    public int getBytesConsumed() {
      return bytesConsumed;
    }
  }
}
