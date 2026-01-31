package com.bcs;

/** BCS error types and exception class. */
public class BcsError extends RuntimeException {

  /** Error type enumeration. */
  public enum Type {
    UNEXPECTED_EOF,
    INVALID_BOOLEAN,
    INVALID_OPTION,
    INVALID_UTF8,
    NON_CANONICAL_ULEB128,
    ULEB128_OVERFLOW,
    EXCEEDED_MAX_LENGTH,
    EXCEEDED_CONTAINER_DEPTH,
    REMAINING_INPUT,
    NON_CANONICAL_MAP,
    UNKNOWN_VARIANT,
    NOT_SUPPORTED,
    VALUE_OUT_OF_RANGE
  }

  private final Type type;

  public BcsError(Type type, String message) {
    super(message);
    this.type = type;
  }

  public Type getType() {
    return type;
  }

  public static BcsError unexpectedEof() {
    return new BcsError(Type.UNEXPECTED_EOF, "Unexpected end of input");
  }

  public static BcsError unexpectedEof(int expected, int available) {
    return new BcsError(
        Type.UNEXPECTED_EOF,
        String.format("Unexpected end of input: expected %d bytes, got %d", expected, available));
  }

  public static BcsError invalidBoolean(int value) {
    return new BcsError(
        Type.INVALID_BOOLEAN,
        String.format("Invalid boolean value: 0x%02x (expected 0x00 or 0x01)", value));
  }

  public static BcsError invalidOption(int value) {
    return new BcsError(
        Type.INVALID_OPTION,
        String.format("Invalid option tag: 0x%02x (expected 0x00 or 0x01)", value));
  }

  public static BcsError invalidUtf8(String reason) {
    return new BcsError(Type.INVALID_UTF8, reason != null ? reason : "Invalid UTF-8 encoding");
  }

  public static BcsError nonCanonicalUleb128() {
    return new BcsError(
        Type.NON_CANONICAL_ULEB128, "Non-canonical ULEB128 encoding (trailing zero bytes)");
  }

  public static BcsError uleb128Overflow() {
    return new BcsError(Type.ULEB128_OVERFLOW, "ULEB128 value overflow (exceeds u32 max)");
  }

  public static BcsError exceededMaxLength(long length) {
    return new BcsError(
        Type.EXCEEDED_MAX_LENGTH,
        String.format("Sequence length %d exceeds maximum allowed (2^31 - 1)", length));
  }

  public static BcsError exceededContainerDepth(String container) {
    String msg =
        (container != null && !container.isEmpty())
            ? String.format("Exceeded maximum container depth (500) while entering %s", container)
            : "Exceeded maximum container depth (500)";
    return new BcsError(Type.EXCEEDED_CONTAINER_DEPTH, msg);
  }

  public static BcsError remainingInput(int remaining) {
    return new BcsError(
        Type.REMAINING_INPUT,
        String.format("Remaining input after deserialization: %d bytes", remaining));
  }

  public static BcsError nonCanonicalMap(String reason) {
    return new BcsError(
        Type.NON_CANONICAL_MAP,
        String.format(
            "Non-canonical map: %s",
            reason != null ? reason : "keys not sorted or contain duplicates"));
  }

  public static BcsError unknownVariant(int index, int maxIndex) {
    return new BcsError(
        Type.UNKNOWN_VARIANT,
        String.format("Unknown enum variant index: %d (max: %d)", index, maxIndex));
  }

  public static BcsError notSupported(String typeName) {
    return new BcsError(Type.NOT_SUPPORTED, String.format("Type not supported: %s", typeName));
  }

  public static BcsError valueOutOfRange(String typeName, Object value) {
    return new BcsError(
        Type.VALUE_OUT_OF_RANGE, String.format("%s value out of range: %s", typeName, value));
  }
}
