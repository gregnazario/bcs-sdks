/**
 * ULEB128 encoding and decoding for BCS.
 *
 * ULEB128 (Unsigned Little-Endian Base 128) is a variable-length encoding
 * for unsigned integers. Each byte contributes 7 bits of data, with the
 * high bit indicating whether more bytes follow.
 */

import { BcsError } from "./errors";

/** Maximum value that can be encoded (u32 max) */
const MAX_U32 = 0xffffffff;

/** Maximum bytes for ULEB128 u32 */
const MAX_BYTES = 5;

/** Pre-allocated buffer for encoding */
const encodeBuffer = new Uint8Array(MAX_BYTES);

/**
 * Encode an unsigned integer as ULEB128 into a buffer.
 * Returns the number of bytes written.
 *
 * @param value - The value to encode
 * @param buffer - Target buffer
 * @param offset - Offset into buffer (default: 0)
 * @returns Number of bytes written
 */
export function encodeInto(value: number, buffer: Uint8Array, offset = 0): number {
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`ULEB128 cannot encode negative values: ${value}`);
  }
  if (value > MAX_U32) {
    throw new Error(`ULEB128 value exceeds u32 max: ${value}`);
  }

  let remaining = value;
  let i = offset;

  do {
    let byte = remaining & 0x7f;
    remaining >>>= 7;
    if (remaining !== 0) {
      byte |= 0x80;
    }
    buffer[i++] = byte;
  } while (remaining !== 0);

  return i - offset;
}

/**
 * Encode an unsigned integer as ULEB128.
 *
 * @param value - The value to encode (must be 0 <= value <= 2^32-1)
 * @returns The ULEB128 encoded bytes
 * @throws Error if value is negative or exceeds u32 max
 *
 * @example
 * ```ts
 * encode(0)      // Uint8Array([0x00])
 * encode(127)    // Uint8Array([0x7F])
 * encode(128)    // Uint8Array([0x80, 0x01])
 * encode(16384)  // Uint8Array([0x80, 0x80, 0x01])
 * ```
 */
export function encode(value: number): Uint8Array {
  const len = encodeInto(value, encodeBuffer, 0);
  return encodeBuffer.slice(0, len);
}

/**
 * Decode a ULEB128 value from a Uint8Array.
 *
 * @param data - The data to decode from
 * @param offset - The offset to start decoding from (default: 0)
 * @returns A tuple of [decodedValue, bytesConsumed]
 * @throws BcsError if decoding fails
 *
 * @example
 * ```ts
 * decode(new Uint8Array([0x00]))           // [0, 1]
 * decode(new Uint8Array([0x7F]))           // [127, 1]
 * decode(new Uint8Array([0x80, 0x01]))     // [128, 2]
 * decode(new Uint8Array([0x80, 0x01, 0xFF]), 0) // [128, 2]
 * ```
 */
export function decode(data: Uint8Array, offset = 0): [number, number] {
  const remaining = data.length - offset;
  if (remaining === 0) {
    throw BcsError.unexpectedEof();
  }

  // Fast path: single byte (values 0-127, very common for lengths)
  const firstByte = data[offset];
  if ((firstByte & 0x80) === 0) {
    return [firstByte, 1];
  }

  // Multi-byte path
  let value = firstByte & 0x7f;
  let shift = 7;
  const maxIter = Math.min(remaining, MAX_BYTES);

  for (let i = 1; i < maxIter; i++) {
    const byte = data[offset + i];
    const digit = byte & 0x7f;
    value |= digit << shift;

    if ((byte & 0x80) === 0) {
      // Check for non-canonical encoding
      if (digit === 0) {
        throw BcsError.nonCanonicalUleb128();
      }
      // Check overflow (only matters for 5th byte)
      if (value > MAX_U32) {
        throw BcsError.uleb128Overflow();
      }
      return [value, i + 1];
    }
    shift += 7;
  }

  if (maxIter === MAX_BYTES) {
    throw BcsError.uleb128Overflow();
  }
  throw BcsError.unexpectedEof();
}

/**
 * Calculate the number of bytes needed to encode a value.
 *
 * @param value - The value to measure
 * @returns The number of bytes needed
 *
 * @example
 * ```ts
 * encodedSize(0)      // 1
 * encodedSize(127)    // 1
 * encodedSize(128)    // 2
 * encodedSize(16384)  // 3
 * ```
 */
export function encodedSize(value: number): number {
  // Optimized with bit comparisons
  if (value < 1 << 7) return 1;
  if (value < 1 << 14) return 2;
  if (value < 1 << 21) return 3;
  if (value < 1 << 28) return 4;
  return 5;
}
