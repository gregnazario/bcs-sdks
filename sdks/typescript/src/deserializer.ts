/**
 * BCS Deserializer - Manual deserialization API.
 *
 * Provides explicit methods for deserializing each BCS type.
 * Use this for full control over deserialization.
 *
 * @example
 * ```ts
 * const data = new Uint8Array([1, 100, 0, 0, 0, 0, 0, 0, 0, 5, 104, 101, 108, 108, 111]);
 * const des = new BcsDeserializer(data);
 * const value1 = des.readU8();    // 1
 * const value2 = des.readU64();   // 100n
 * const value3 = des.readString(); // "hello"
 * des.checkEnd(); // Verify no remaining bytes
 * ```
 */

import { BcsError } from "./errors";
import * as uleb128 from "./uleb128";
import { MAX_SEQUENCE_LENGTH } from "./serializer";

// Cached TextDecoder for string deserialization
const textDecoder = new TextDecoder("utf-8", { fatal: true });

// Cached sign bit constants
const SIGN_BIT_64 = 1n << 63n;
const SIGN_BIT_128 = 1n << 127n;
const SIGN_BIT_256 = 1n << 255n;
const MASK_64 = 1n << 64n;
const MASK_128 = 1n << 128n;
const MASK_256 = 1n << 256n;

// Container depth limit
const MAX_CONTAINER_DEPTH = 500;

/**
 * BCS Deserializer class.
 */
export class BcsDeserializer {
  private data: Uint8Array;
  private offset: number = 0;
  private depth: number = 0;

  /**
   * Create a new deserializer.
   * @param data - The data to deserialize from
   */
  constructor(data: Uint8Array) {
    this.data = data;
  }

  // ==========================================================================
  // BOOLEAN
  // ==========================================================================

  /**
   * Deserialize a boolean value.
   */
  readBool(): boolean {
    if (this.offset >= this.data.length) {
      throw BcsError.unexpectedEof(1, 0);
    }
    const byte = this.data[this.offset++];
    if (byte === 0) return false;
    if (byte === 1) return true;
    throw BcsError.invalidBoolean(byte);
  }

  // ==========================================================================
  // UNSIGNED INTEGERS
  // ==========================================================================

  /**
   * Deserialize an unsigned 8-bit integer.
   */
  readU8(): number {
    if (this.offset >= this.data.length) {
      throw BcsError.unexpectedEof(1, 0);
    }
    return this.data[this.offset++];
  }

  /**
   * Deserialize an unsigned 16-bit integer (little-endian).
   */
  readU16(): number {
    if (this.offset + 2 > this.data.length) {
      throw BcsError.unexpectedEof(2, this.data.length - this.offset);
    }
    const value = this.data[this.offset] | (this.data[this.offset + 1] << 8);
    this.offset += 2;
    return value;
  }

  /**
   * Deserialize an unsigned 32-bit integer (little-endian).
   */
  readU32(): number {
    if (this.offset + 4 > this.data.length) {
      throw BcsError.unexpectedEof(4, this.data.length - this.offset);
    }
    // Unrolled for performance
    const value =
      this.data[this.offset] |
      (this.data[this.offset + 1] << 8) |
      (this.data[this.offset + 2] << 16) |
      ((this.data[this.offset + 3] << 24) >>> 0);
    this.offset += 4;
    return value >>> 0; // Ensure unsigned
  }

  /**
   * Deserialize an unsigned 64-bit integer (little-endian).
   */
  readU64(): bigint {
    if (this.offset + 8 > this.data.length) {
      throw BcsError.unexpectedEof(8, this.data.length - this.offset);
    }
    return this.readBigIntLE(8);
  }

  /**
   * Deserialize an unsigned 128-bit integer (little-endian).
   */
  readU128(): bigint {
    if (this.offset + 16 > this.data.length) {
      throw BcsError.unexpectedEof(16, this.data.length - this.offset);
    }
    return this.readBigIntLE(16);
  }

  /**
   * Deserialize an unsigned 256-bit integer (little-endian).
   */
  readU256(): bigint {
    if (this.offset + 32 > this.data.length) {
      throw BcsError.unexpectedEof(32, this.data.length - this.offset);
    }
    return this.readBigIntLE(32);
  }

  // ==========================================================================
  // SIGNED INTEGERS
  // ==========================================================================

  /**
   * Deserialize a signed 8-bit integer (two's complement).
   */
  readI8(): number {
    const unsigned = this.readU8();
    return unsigned >= 128 ? unsigned - 256 : unsigned;
  }

  /**
   * Deserialize a signed 16-bit integer (two's complement, little-endian).
   */
  readI16(): number {
    const unsigned = this.readU16();
    return unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
  }

  /**
   * Deserialize a signed 32-bit integer (two's complement, little-endian).
   */
  readI32(): number {
    const unsigned = this.readU32();
    return unsigned >= 0x80000000 ? unsigned - 0x100000000 : unsigned;
  }

  /**
   * Deserialize a signed 64-bit integer (two's complement, little-endian).
   */
  readI64(): bigint {
    const unsigned = this.readU64();
    return unsigned >= SIGN_BIT_64 ? unsigned - MASK_64 : unsigned;
  }

  /**
   * Deserialize a signed 128-bit integer (two's complement, little-endian).
   */
  readI128(): bigint {
    const unsigned = this.readU128();
    return unsigned >= SIGN_BIT_128 ? unsigned - MASK_128 : unsigned;
  }

  /**
   * Deserialize a signed 256-bit integer (two's complement, little-endian).
   */
  readI256(): bigint {
    const unsigned = this.readU256();
    return unsigned >= SIGN_BIT_256 ? unsigned - MASK_256 : unsigned;
  }

  // ==========================================================================
  // ULEB128
  // ==========================================================================

  /**
   * Deserialize a ULEB128-encoded unsigned integer.
   */
  readUleb128(): number {
    const [value, bytesRead] = uleb128.decode(this.data, this.offset);
    this.offset += bytesRead;
    return value;
  }

  // ==========================================================================
  // BYTES AND STRINGS
  // ==========================================================================

  /**
   * Deserialize a byte array (length-prefixed with ULEB128).
   */
  readBytes(): Uint8Array {
    const length = this.readUleb128();
    if (length > MAX_SEQUENCE_LENGTH) {
      throw BcsError.exceededMaxLength(length);
    }
    return this.readFixedBytes(length);
  }

  /**
   * Deserialize a UTF-8 string (length-prefixed with ULEB128).
   */
  readString(): string {
    const length = this.readUleb128();
    if (length > MAX_SEQUENCE_LENGTH) {
      throw BcsError.exceededMaxLength(length);
    }
    if (this.offset + length > this.data.length) {
      throw BcsError.unexpectedEof(length, this.data.length - this.offset);
    }
    // Use subarray for zero-copy view
    const bytes = this.data.subarray(this.offset, this.offset + length);
    try {
      const str = textDecoder.decode(bytes);
      this.offset += length;
      return str;
    } catch {
      throw BcsError.invalidUtf8();
    }
  }

  /**
   * Deserialize fixed-length bytes (no length prefix).
   * Returns a copy of the bytes.
   */
  readFixedBytes(length: number): Uint8Array {
    if (this.offset + length > this.data.length) {
      throw BcsError.unexpectedEof(length, this.data.length - this.offset);
    }
    // Use slice to create a copy (maintains existing behavior)
    const bytes = this.data.slice(this.offset, this.offset + length);
    this.offset += length;
    return bytes;
  }

  /**
   * Deserialize fixed-length bytes as a view (no copy, no length prefix).
   * WARNING: The returned view is only valid while the deserializer's data is not modified.
   */
  readFixedBytesView(length: number): Uint8Array {
    if (this.offset + length > this.data.length) {
      throw BcsError.unexpectedEof(length, this.data.length - this.offset);
    }
    // Use subarray for zero-copy view
    const bytes = this.data.subarray(this.offset, this.offset + length);
    this.offset += length;
    return bytes;
  }

  // ==========================================================================
  // OPTION
  // ==========================================================================

  /**
   * Deserialize an optional value.
   *
   * @param deserializer - Function to deserialize the inner value
   * @returns The value or null if None
   */
  readOption<T>(deserializer: (des: BcsDeserializer) => T): T | null {
    if (this.offset >= this.data.length) {
      throw BcsError.unexpectedEof(1, 0);
    }
    const tag = this.data[this.offset++];
    if (tag === 0) return null;
    if (tag === 1) return deserializer(this);
    throw BcsError.invalidOption(tag);
  }

  // ==========================================================================
  // VECTOR
  // ==========================================================================

  /**
   * Deserialize a vector of values.
   *
   * @param deserializer - Function to deserialize each element
   */
  readVector<T>(deserializer: (des: BcsDeserializer) => T): T[] {
    const length = this.readUleb128();
    // Validate length is within safe bounds
    if (length > MAX_SEQUENCE_LENGTH || !Number.isSafeInteger(length)) {
      throw BcsError.exceededMaxLength(length);
    }
    // Pre-allocate array for better performance
    const result: T[] = new Array(length);
    for (let i = 0; i < length; i++) {
      result[i] = deserializer(this);
    }
    return result;
  }

  // ==========================================================================
  // ENUM
  // ==========================================================================

  /**
   * Read an enum variant index (ULEB128).
   */
  readVariantIndex(): number {
    return this.readUleb128();
  }

  // ==========================================================================
  // CONTAINER DEPTH
  // ==========================================================================

  /**
   * Enter a struct container for depth tracking.
   * @throws BcsError if container depth exceeds MAX_CONTAINER_DEPTH (500)
   */
  enterStruct(): this {
    this.enterContainer("struct");
    return this;
  }

  /**
   * Leave a struct container.
   */
  leaveStruct(): this {
    this.leaveContainer();
    return this;
  }

  /**
   * Enter an enum container for depth tracking and read variant index.
   * @returns The enum variant index
   * @throws BcsError if container depth exceeds MAX_CONTAINER_DEPTH (500)
   */
  enterEnum(): number {
    this.enterContainer("enum");
    return this.readVariantIndex();
  }

  /**
   * Leave an enum container.
   */
  leaveEnum(): this {
    this.leaveContainer();
    return this;
  }

  /**
   * Get the current container depth.
   */
  get containerDepth(): number {
    return this.depth;
  }

  private enterContainer(name: string): void {
    if (this.depth >= MAX_CONTAINER_DEPTH) {
      throw BcsError.exceededContainerDepth(name);
    }
    this.depth++;
  }

  private leaveContainer(): void {
    if (this.depth > 0) {
      this.depth--;
    }
  }

  // ==========================================================================
  // MAP
  // ==========================================================================

  /**
   * Deserialize a map (verifying sorted keys).
   *
   * @param keyDeserializer - Function to deserialize keys
   * @param valueDeserializer - Function to deserialize values
   */
  readMap<K, V>(
    keyDeserializer: (des: BcsDeserializer) => K,
    valueDeserializer: (des: BcsDeserializer) => V
  ): Map<K, V> {
    const length = this.readUleb128();
    if (length > MAX_SEQUENCE_LENGTH) {
      throw BcsError.exceededMaxLength(length);
    }

    const result = new Map<K, V>();
    let prevKeyBytes: Uint8Array | null = null;

    for (let i = 0; i < length; i++) {
      // Record position before reading key
      const keyStart = this.offset;
      const key = keyDeserializer(this);
      const keyEnd = this.offset;
      // Use subarray for zero-copy view (only used for comparison)
      const keyBytes = this.data.subarray(keyStart, keyEnd);

      // Verify key order
      if (prevKeyBytes !== null) {
        const cmp = compareBytes(prevKeyBytes, keyBytes);
        if (cmp === 0) {
          throw BcsError.nonCanonicalMap("duplicate key");
        }
        if (cmp > 0) {
          throw BcsError.nonCanonicalMap("keys not sorted");
        }
      }
      // Copy key bytes only when storing for next comparison
      prevKeyBytes = this.data.slice(keyStart, keyEnd);

      const value = valueDeserializer(this);
      result.set(key, value);
    }

    return result;
  }

  // ==========================================================================
  // UTILITY
  // ==========================================================================

  /**
   * Check that all input has been consumed.
   * @throws BcsError if there is remaining input
   */
  checkEnd(): void {
    if (this.offset < this.data.length) {
      throw BcsError.remainingInput(this.data.length - this.offset);
    }
  }

  /**
   * Get the number of remaining bytes.
   */
  get remaining(): number {
    return this.data.length - this.offset;
  }

  /**
   * Get the current offset.
   */
  get position(): number {
    return this.offset;
  }

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  /** Optimized BigInt read - processes from high to low byte for better performance */
  private readBigIntLE(byteLength: number): bigint {
    let value = 0n;
    for (let i = byteLength - 1; i >= 0; i--) {
      value = (value << 8n) | BigInt(this.data[this.offset + i]);
    }
    this.offset += byteLength;
    return value;
  }
}

/**
 * Compare two byte arrays lexicographically.
 */
function compareBytes(a: Uint8Array, b: Uint8Array): number {
  const minLen = Math.min(a.length, b.length);
  for (let i = 0; i < minLen; i++) {
    if (a[i] !== b[i]) {
      return a[i] - b[i];
    }
  }
  return a.length - b.length;
}
