/// BCS Error types and exceptions
library;

/// Error types for BCS operations
enum BcsErrorType {
  unexpectedEof,
  invalidBoolean,
  nonCanonicalUleb128,
  uleb128Overflow,
  exceededMaxLength,
  exceededContainerDepth,
  invalidUtf8,
  nonCanonicalMap,
  duplicateMapKey,
  integerOutOfRange,
  remainingInput,
  invalidOption,
}

/// Exception thrown for BCS serialization/deserialization errors
class BcsError implements Exception {
  /// Creates a BCS error with the given type and message.
  BcsError(this.type, this.message);

  /// Creates an error for unexpected end of input.
  factory BcsError.unexpectedEof() =>
      BcsError(BcsErrorType.unexpectedEof, 'Unexpected end of input');

  /// Creates an error for invalid boolean value.
  factory BcsError.invalidBoolean(int value) => BcsError(
        BcsErrorType.invalidBoolean,
        'Invalid boolean value: $value (expected 0 or 1)',
      );

  /// Creates an error for non-canonical ULEB128 encoding.
  factory BcsError.nonCanonicalUleb128() => BcsError(
        BcsErrorType.nonCanonicalUleb128,
        'ULEB128 encoding is not canonical (has trailing zeros)',
      );

  /// Creates an error for ULEB128 overflow.
  factory BcsError.uleb128Overflow() =>
      BcsError(BcsErrorType.uleb128Overflow, 'ULEB128 value overflows u32');

  /// Creates an error for exceeded maximum length.
  factory BcsError.exceededMaxLength(int length, int max) => BcsError(
        BcsErrorType.exceededMaxLength,
        'Sequence length $length exceeds maximum $max',
      );

  /// Creates an error for exceeded container depth.
  factory BcsError.exceededContainerDepth(int depth, int max) => BcsError(
        BcsErrorType.exceededContainerDepth,
        'Container depth $depth exceeds maximum $max',
      );

  /// Creates an error for invalid UTF-8.
  factory BcsError.invalidUtf8() =>
      BcsError(BcsErrorType.invalidUtf8, 'Invalid UTF-8 encoding');

  /// Creates an error for non-canonical map ordering.
  factory BcsError.nonCanonicalMap() => BcsError(
        BcsErrorType.nonCanonicalMap,
        'Map keys are not in sorted order',
      );

  /// Creates an error for duplicate map key.
  factory BcsError.duplicateMapKey() =>
      BcsError(BcsErrorType.duplicateMapKey, 'Duplicate key in map');

  /// Creates an error for integer out of range.
  factory BcsError.integerOutOfRange(String typeName) => BcsError(
        BcsErrorType.integerOutOfRange,
        'Integer value out of range for $typeName',
      );

  /// Creates an error for remaining input after deserialization.
  factory BcsError.remainingInput(int remaining) => BcsError(
        BcsErrorType.remainingInput,
        'Input has $remaining remaining bytes after deserialization',
      );

  /// Creates an error for invalid option tag.
  factory BcsError.invalidOption(int value) => BcsError(
        BcsErrorType.invalidOption,
        'Invalid option tag: $value (expected 0 or 1)',
      );

  /// The type of error.
  final BcsErrorType type;

  /// The error message.
  final String message;

  @override
  String toString() => 'BcsError($type): $message';
}
