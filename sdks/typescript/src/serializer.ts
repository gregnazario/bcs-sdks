/**
 * BCS Serializer - Manual serialization API.
 *
 * Provides explicit methods for serializing each BCS type.
 * Use this for full control over serialization.
 *
 * @example
 * ```ts
 * const ser = new BcsSerializer();
 * ser.writeU8(1);
 * ser.writeU64(100n);
 * ser.writeString("hello");
 * const bytes = ser.toBytes();
 * ```
 */

import { BcsError } from "./errors";
import * as uleb128 from "./uleb128";

// Constants
export const MAX_SEQUENCE_LENGTH = 2147483647; // 2^31 - 1
export const MAX_CONTAINER_DEPTH = 500;

// Integer bounds
const U8_MAX = 0xff;
const U16_MAX = 0xffff;
const U32_MAX = 0xffffffff;
const U64_MAX = 0xffffffffffffffffn;
const U128_MAX = (1n << 128n) - 1n;
const U256_MAX = (1n << 256n) - 1n;

const I8_MIN = -128;
const I8_MAX = 127;
const I16_MIN = -32768;
const I16_MAX = 32767;
const I32_MIN = -2147483648;
const I32_MAX = 2147483647;
const I64_MIN = -(1n << 63n);
const I64_MAX = (1n << 63n) - 1n;
const I128_MIN = -(1n << 127n);
const I128_MAX = (1n << 127n) - 1n;
const I256_MIN = -(1n << 255n);
const I256_MAX = (1n << 255n) - 1n;

// Cached TextEncoder for string serialization
const textEncoder = new TextEncoder();

// Initial buffer size
const INITIAL_CAPACITY = 256;

/**
 * BCS Serializer class.
 */
export class BcsSerializer {
  private buffer: Uint8Array;
  private size: number = 0;
  private depth: number = 0;

  constructor(initialCapacity: number = INITIAL_CAPACITY) {
    this.buffer = new Uint8Array(initialCapacity);
  }

  /** Ensure buffer has capacity for additional bytes */
  private ensureCapacity(needed: number): void {
    const required = this.size + needed;
    if (required <= this.buffer.length) return;

    // Grow by doubling or to required size
    let newCapacity = this.buffer.length * 2;
    if (newCapacity < required) newCapacity = required;
    const newBuffer = new Uint8Array(newCapacity);
    newBuffer.set(this.buffer.subarray(0, this.size));
    this.buffer = newBuffer;
  }

  // ==========================================================================
  // BOOLEAN
  // ==========================================================================

  /**
   * Serialize a boolean value.
   */
  writeBool(value: boolean): this {
    this.ensureCapacity(1);
    this.buffer[this.size++] = value ? 1 : 0;
    return this;
  }

  // ==========================================================================
  // UNSIGNED INTEGERS
  // ==========================================================================

  /**
   * Serialize an unsigned 8-bit integer.
   */
  writeU8(value: number): this {
    if (!Number.isInteger(value) || value < 0 || value > U8_MAX) {
      throw BcsError.valueOutOfRange("u8", value);
    }
    this.ensureCapacity(1);
    this.buffer[this.size++] = value;
    return this;
  }

  /**
   * Serialize an unsigned 16-bit integer (little-endian).
   */
  writeU16(value: number): this {
    if (!Number.isInteger(value) || value < 0 || value > U16_MAX) {
      throw BcsError.valueOutOfRange("u16", value);
    }
    this.ensureCapacity(2);
    this.buffer[this.size] = value & 0xff;
    this.buffer[this.size + 1] = (value >> 8) & 0xff;
    this.size += 2;
    return this;
  }

  /**
   * Serialize an unsigned 32-bit integer (little-endian).
   */
  writeU32(value: number): this {
    if (!Number.isInteger(value) || value < 0 || value > U32_MAX) {
      throw BcsError.valueOutOfRange("u32", value);
    }
    this.ensureCapacity(4);
    // Unrolled for performance
    this.buffer[this.size] = value & 0xff;
    this.buffer[this.size + 1] = (value >> 8) & 0xff;
    this.buffer[this.size + 2] = (value >> 16) & 0xff;
    this.buffer[this.size + 3] = (value >>> 24) & 0xff;
    this.size += 4;
    return this;
  }

  /**
   * Serialize an unsigned 64-bit integer (little-endian).
   */
  writeU64(value: bigint): this {
    if (value < 0n || value > U64_MAX) {
      throw BcsError.valueOutOfRange("u64", value);
    }
    this.writeBigIntLE(value, 8);
    return this;
  }

  /**
   * Serialize an unsigned 128-bit integer (little-endian).
   */
  writeU128(value: bigint): this {
    if (value < 0n || value > U128_MAX) {
      throw BcsError.valueOutOfRange("u128", value);
    }
    this.writeBigIntLE(value, 16);
    return this;
  }

  /**
   * Serialize an unsigned 256-bit integer (little-endian).
   */
  writeU256(value: bigint): this {
    if (value < 0n || value > U256_MAX) {
      throw BcsError.valueOutOfRange("u256", value);
    }
    this.writeBigIntLE(value, 32);
    return this;
  }

  // ==========================================================================
  // SIGNED INTEGERS
  // ==========================================================================

  /**
   * Serialize a signed 8-bit integer (two's complement).
   */
  writeI8(value: number): this {
    if (!Number.isInteger(value) || value < I8_MIN || value > I8_MAX) {
      throw BcsError.valueOutOfRange("i8", value);
    }
    this.ensureCapacity(1);
    this.buffer[this.size++] = value < 0 ? value + 256 : value;
    return this;
  }

  /**
   * Serialize a signed 16-bit integer (two's complement, little-endian).
   */
  writeI16(value: number): this {
    if (!Number.isInteger(value) || value < I16_MIN || value > I16_MAX) {
      throw BcsError.valueOutOfRange("i16", value);
    }
    const unsigned = value < 0 ? value + 0x10000 : value;
    this.ensureCapacity(2);
    this.buffer[this.size] = unsigned & 0xff;
    this.buffer[this.size + 1] = (unsigned >> 8) & 0xff;
    this.size += 2;
    return this;
  }

  /**
   * Serialize a signed 32-bit integer (two's complement, little-endian).
   */
  writeI32(value: number): this {
    if (!Number.isInteger(value) || value < I32_MIN || value > I32_MAX) {
      throw BcsError.valueOutOfRange("i32", value);
    }
    const unsigned = value < 0 ? value + 0x100000000 : value;
    this.ensureCapacity(4);
    this.buffer[this.size] = unsigned & 0xff;
    this.buffer[this.size + 1] = (unsigned >> 8) & 0xff;
    this.buffer[this.size + 2] = (unsigned >> 16) & 0xff;
    this.buffer[this.size + 3] = (unsigned >>> 24) & 0xff;
    this.size += 4;
    return this;
  }

  /**
   * Serialize a signed 64-bit integer (two's complement, little-endian).
   */
  writeI64(value: bigint): this {
    if (value < I64_MIN || value > I64_MAX) {
      throw BcsError.valueOutOfRange("i64", value);
    }
    const unsigned = value < 0n ? value + (1n << 64n) : value;
    this.writeBigIntLE(unsigned, 8);
    return this;
  }

  /**
   * Serialize a signed 128-bit integer (two's complement, little-endian).
   */
  writeI128(value: bigint): this {
    if (value < I128_MIN || value > I128_MAX) {
      throw BcsError.valueOutOfRange("i128", value);
    }
    const unsigned = value < 0n ? value + (1n << 128n) : value;
    this.writeBigIntLE(unsigned, 16);
    return this;
  }

  /**
   * Serialize a signed 256-bit integer (two's complement, little-endian).
   */
  writeI256(value: bigint): this {
    if (value < I256_MIN || value > I256_MAX) {
      throw BcsError.valueOutOfRange("i256", value);
    }
    const unsigned = value < 0n ? value + (1n << 256n) : value;
    this.writeBigIntLE(unsigned, 32);
    return this;
  }

  // ==========================================================================
  // ULEB128
  // ==========================================================================

  /**
   * Serialize a ULEB128-encoded unsigned integer.
   */
  writeUleb128(value: number): this {
    // Fast path for single byte (0-127)
    if (value < 0x80) {
      this.ensureCapacity(1);
      this.buffer[this.size++] = value;
      return this;
    }
    // Multi-byte path
    this.ensureCapacity(5);
    const len = uleb128.encodeInto(value, this.buffer, this.size);
    this.size += len;
    return this;
  }

  // ==========================================================================
  // BYTES AND STRINGS
  // ==========================================================================

  /**
   * Serialize a byte array (length-prefixed with ULEB128).
   */
  writeBytes(value: Uint8Array): this {
    if (value.length > MAX_SEQUENCE_LENGTH) {
      throw BcsError.exceededMaxLength(value.length);
    }
    // Pre-allocate for length + data
    const ulebSize = uleb128.encodedSize(value.length);
    this.ensureCapacity(ulebSize + value.length);
    this.writeUleb128(value.length);
    this.buffer.set(value, this.size);
    this.size += value.length;
    return this;
  }

  /**
   * Serialize a UTF-8 string (length-prefixed with ULEB128).
   */
  writeString(value: string): this {
    const bytes = textEncoder.encode(value);
    return this.writeBytes(bytes);
  }

  /**
   * Serialize fixed-length bytes (no length prefix).
   */
  writeFixedBytes(value: Uint8Array, length: number): this {
    if (value.length !== length) {
      throw new Error(`Expected ${length} bytes, got ${value.length}`);
    }
    this.ensureCapacity(length);
    this.buffer.set(value, this.size);
    this.size += length;
    return this;
  }

  // ==========================================================================
  // OPTION
  // ==========================================================================

  /**
   * Serialize an optional value.
   *
   * @param value - The value or null/undefined
   * @param serializer - Function to serialize the inner value
   */
  writeOption<T>(
    value: T | null | undefined,
    serializer: (ser: BcsSerializer, v: T) => void
  ): this {
    if (value === null || value === undefined) {
      this.ensureCapacity(1);
      this.buffer[this.size++] = 0;
    } else {
      this.ensureCapacity(1);
      this.buffer[this.size++] = 1;
      serializer(this, value);
    }
    return this;
  }

  // ==========================================================================
  // VECTOR
  // ==========================================================================

  /**
   * Serialize a vector of values.
   *
   * @param values - The array of values
   * @param serializer - Function to serialize each element
   */
  writeVector<T>(values: T[], serializer: (ser: BcsSerializer, v: T) => void): this {
    if (values.length > MAX_SEQUENCE_LENGTH) {
      throw BcsError.exceededMaxLength(values.length);
    }
    this.writeUleb128(values.length);
    for (const value of values) {
      serializer(this, value);
    }
    return this;
  }

  // ==========================================================================
  // ENUM
  // ==========================================================================

  /**
   * Write an enum variant index (ULEB128).
   */
  writeVariantIndex(index: number): this {
    return this.writeUleb128(index);
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
   * Enter an enum container for depth tracking and write variant index.
   * @param variantIndex - The enum variant index
   * @throws BcsError if container depth exceeds MAX_CONTAINER_DEPTH (500)
   */
  enterEnum(variantIndex: number): this {
    this.enterContainer("enum");
    this.writeVariantIndex(variantIndex);
    return this;
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
   * Serialize a map (sorted by key bytes).
   *
   * @param entries - The map entries as an array of [key, value] pairs or Map
   * @param keySerializer - Function to serialize keys
   * @param valueSerializer - Function to serialize values
   */
  writeMap<K, V>(
    entries: Map<K, V> | [K, V][],
    keySerializer: (ser: BcsSerializer, k: K) => void,
    valueSerializer: (ser: BcsSerializer, v: V) => void
  ): this {
    const entryArray = entries instanceof Map ? Array.from(entries.entries()) : entries;

    if (entryArray.length > MAX_SEQUENCE_LENGTH) {
      throw BcsError.exceededMaxLength(entryArray.length);
    }

    // Serialize keys to get bytes for sorting
    const keyBytesEntries = entryArray.map(([key, value]) => {
      const keySer = new BcsSerializer();
      keySerializer(keySer, key);
      return { keyBytes: keySer.toBytes(), key, value };
    });

    // Sort by key bytes
    keyBytesEntries.sort((a, b) => compareBytes(a.keyBytes, b.keyBytes));

    // Write length and sorted entries
    this.writeUleb128(keyBytesEntries.length);
    for (const { keyBytes, value } of keyBytesEntries) {
      this.ensureCapacity(keyBytes.length);
      for (const byte of keyBytes) {
        this.buffer[this.size++] = byte;
      }
      valueSerializer(this, value);
    }

    return this;
  }

  // ==========================================================================
  // UTILITY
  // ==========================================================================

  /**
   * Get the serialized bytes.
   */
  toBytes(): Uint8Array {
    return this.buffer.slice(0, this.size);
  }

  /**
   * Get the current length in bytes.
   */
  get length(): number {
    return this.size;
  }

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  private writeBigIntLE(value: bigint, byteLength: number): void {
    this.ensureCapacity(byteLength);
    let v = value;
    for (let i = 0; i < byteLength; i++) {
      this.buffer[this.size + i] = Number(v & 0xffn);
      v >>= 8n;
    }
    this.size += byteLength;
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
