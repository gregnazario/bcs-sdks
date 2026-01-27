/**
 * Binary Canonical Serialization (BCS) for TypeScript.
 *
 * BCS is a deterministic binary serialization format that guarantees
 * canonical representation - every value has exactly one valid encoding.
 *
 * ## Quick Start
 *
 * ```ts
 * import { BcsSerializer, BcsDeserializer } from "@bcs-sdks/bcs";
 *
 * // Serialization
 * const ser = new BcsSerializer();
 * ser.writeU8(1);
 * ser.writeU64(100n);
 * ser.writeString("hello");
 * const bytes = ser.toBytes();
 *
 * // Deserialization
 * const des = new BcsDeserializer(bytes);
 * const value1 = des.readU8();
 * const value2 = des.readU64();
 * const value3 = des.readString();
 * des.checkEnd();
 * ```
 *
 * @packageDocumentation
 */

// Core classes
export { BcsSerializer, MAX_SEQUENCE_LENGTH, MAX_CONTAINER_DEPTH } from "./serializer";
export { BcsDeserializer } from "./deserializer";

// Error types
export { BcsError, type BcsErrorType } from "./errors";

// ULEB128 utilities
export * as uleb128 from "./uleb128";

// Re-export for convenience
import { BcsSerializer } from "./serializer";
import { BcsDeserializer } from "./deserializer";

/**
 * Convenience function to serialize a value using a serializer function.
 *
 * @param serializer - Function that writes to a BcsSerializer
 * @returns The serialized bytes
 *
 * @example
 * ```ts
 * const bytes = serialize((ser) => {
 *   ser.writeU8(1);
 *   ser.writeU64(100n);
 * });
 * ```
 */
export function serialize(serializer: (ser: BcsSerializer) => void): Uint8Array {
  const ser = new BcsSerializer();
  serializer(ser);
  return ser.toBytes();
}

/**
 * Convenience function to deserialize a value using a deserializer function.
 *
 * @param data - The data to deserialize
 * @param deserializer - Function that reads from a BcsDeserializer
 * @param checkEnd - Whether to verify all input was consumed (default: true)
 * @returns The deserialized value
 *
 * @example
 * ```ts
 * const [a, b] = deserialize(bytes, (des) => {
 *   return [des.readU8(), des.readU64()];
 * });
 * ```
 */
export function deserialize<T>(
  data: Uint8Array,
  deserializer: (des: BcsDeserializer) => T,
  checkEnd = true
): T {
  const des = new BcsDeserializer(data);
  const result = deserializer(des);
  if (checkEnd) {
    des.checkEnd();
  }
  return result;
}

// Convenience functions for common types

/**
 * Serialize a u8 value.
 */
export function serializeU8(value: number): Uint8Array {
  return serialize((ser) => ser.writeU8(value));
}

/**
 * Serialize a u64 value.
 */
export function serializeU64(value: bigint): Uint8Array {
  return serialize((ser) => ser.writeU64(value));
}

/**
 * Serialize a string value.
 */
export function serializeString(value: string): Uint8Array {
  return serialize((ser) => ser.writeString(value));
}

/**
 * Serialize a bytes value.
 */
export function serializeBytes(value: Uint8Array): Uint8Array {
  return serialize((ser) => ser.writeBytes(value));
}

/**
 * Deserialize a u8 value.
 */
export function deserializeU8(data: Uint8Array): number {
  return deserialize(data, (des) => des.readU8());
}

/**
 * Deserialize a u64 value.
 */
export function deserializeU64(data: Uint8Array): bigint {
  return deserialize(data, (des) => des.readU64());
}

/**
 * Deserialize a string value.
 */
export function deserializeString(data: Uint8Array): string {
  return deserialize(data, (des) => des.readString());
}

/**
 * Deserialize a bytes value.
 */
export function deserializeBytes(data: Uint8Array): Uint8Array {
  return deserialize(data, (des) => des.readBytes());
}

/**
 * Convert a hex string to Uint8Array.
 */
export function hexToBytes(hex: string): Uint8Array {
  const normalized = hex.startsWith("0x") ? hex.slice(2) : hex;
  const bytes = new Uint8Array(normalized.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(normalized.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

/**
 * Convert a Uint8Array to hex string.
 */
export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
