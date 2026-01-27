/**
 * BCS Error types.
 */

export type BcsErrorType =
  | "UNEXPECTED_EOF"
  | "INVALID_BOOLEAN"
  | "INVALID_OPTION"
  | "INVALID_UTF8"
  | "NON_CANONICAL_ULEB128"
  | "ULEB128_OVERFLOW"
  | "EXCEEDED_MAX_LENGTH"
  | "EXCEEDED_CONTAINER_DEPTH"
  | "REMAINING_INPUT"
  | "NON_CANONICAL_MAP"
  | "UNKNOWN_VARIANT"
  | "NOT_SUPPORTED"
  | "VALUE_OUT_OF_RANGE";

/**
 * BCS Error class for serialization/deserialization errors.
 */
export class BcsError extends Error {
  readonly type: BcsErrorType;

  constructor(type: BcsErrorType, message: string) {
    super(message);
    this.name = "BcsError";
    this.type = type;
  }

  static unexpectedEof(expected?: number, available?: number): BcsError {
    const msg =
      expected !== undefined && available !== undefined
        ? `Unexpected end of input: expected ${expected} bytes, got ${available}`
        : "Unexpected end of input";
    return new BcsError("UNEXPECTED_EOF", msg);
  }

  static invalidBoolean(value: number): BcsError {
    const hex = value.toString(16).padStart(2, "0");
    return new BcsError(
      "INVALID_BOOLEAN",
      `Invalid boolean value: 0x${hex} (expected 0x00 or 0x01)`
    );
  }

  static invalidOption(value: number): BcsError {
    const hex = value.toString(16).padStart(2, "0");
    return new BcsError("INVALID_OPTION", `Invalid option tag: 0x${hex} (expected 0x00 or 0x01)`);
  }

  static invalidUtf8(reason = "Invalid UTF-8 encoding"): BcsError {
    return new BcsError("INVALID_UTF8", reason);
  }

  static nonCanonicalUleb128(): BcsError {
    return new BcsError(
      "NON_CANONICAL_ULEB128",
      "Non-canonical ULEB128 encoding (trailing zero bytes)"
    );
  }

  static uleb128Overflow(): BcsError {
    return new BcsError("ULEB128_OVERFLOW", "ULEB128 value overflow (exceeds u32 max)");
  }

  static exceededMaxLength(length: number): BcsError {
    return new BcsError(
      "EXCEEDED_MAX_LENGTH",
      `Sequence length ${length} exceeds maximum allowed (2^31 - 1)`
    );
  }

  static exceededContainerDepth(container = ""): BcsError {
    const msg = container
      ? `Exceeded maximum container depth (500) while entering ${container}`
      : "Exceeded maximum container depth (500)";
    return new BcsError("EXCEEDED_CONTAINER_DEPTH", msg);
  }

  static remainingInput(remaining: number): BcsError {
    return new BcsError(
      "REMAINING_INPUT",
      `Remaining input after deserialization: ${remaining} bytes`
    );
  }

  static nonCanonicalMap(reason = "keys not sorted or contain duplicates"): BcsError {
    return new BcsError("NON_CANONICAL_MAP", `Non-canonical map: ${reason}`);
  }

  static unknownVariant(index: number, maxIndex: number): BcsError {
    return new BcsError(
      "UNKNOWN_VARIANT",
      `Unknown enum variant index: ${index} (max: ${maxIndex})`
    );
  }

  static notSupported(typeName: string): BcsError {
    return new BcsError("NOT_SUPPORTED", `Type not supported: ${typeName}`);
  }

  static valueOutOfRange(typeName: string, value: bigint | number): BcsError {
    return new BcsError("VALUE_OUT_OF_RANGE", `${typeName} value out of range: ${value}`);
  }
}
