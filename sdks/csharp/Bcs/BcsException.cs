namespace Bcs;

/// <summary>
/// BCS error types.
/// </summary>
public enum BcsErrorType
{
    /// <summary>Unexpected end of input.</summary>
    UnexpectedEof,
    /// <summary>Invalid boolean value.</summary>
    InvalidBoolean,
    /// <summary>Invalid option tag.</summary>
    InvalidOption,
    /// <summary>Invalid UTF-8 encoding.</summary>
    InvalidUtf8,
    /// <summary>Non-canonical ULEB128 encoding.</summary>
    NonCanonicalUleb128,
    /// <summary>ULEB128 value overflow.</summary>
    Uleb128Overflow,
    /// <summary>Sequence length exceeded maximum.</summary>
    ExceededMaxLength,
    /// <summary>Container depth exceeded maximum.</summary>
    ExceededContainerDepth,
    /// <summary>Remaining input after deserialization.</summary>
    RemainingInput,
    /// <summary>Map keys not sorted or has duplicates.</summary>
    NonCanonicalMap,
    /// <summary>Unknown enum variant index.</summary>
    UnknownVariant,
    /// <summary>Type not supported.</summary>
    NotSupported,
    /// <summary>Value out of range.</summary>
    ValueOutOfRange
}

/// <summary>
/// Exception thrown during BCS serialization/deserialization.
/// </summary>
public class BcsException : Exception
{
    /// <summary>
    /// Gets the error type.
    /// </summary>
    public BcsErrorType ErrorType { get; }

    /// <summary>
    /// Creates a new BCS exception.
    /// </summary>
    public BcsException(BcsErrorType errorType, string message)
        : base(message)
    {
        ErrorType = errorType;
    }

    /// <summary>Creates an unexpected EOF error.</summary>
    public static BcsException UnexpectedEof()
        => new(BcsErrorType.UnexpectedEof, "Unexpected end of input");

    /// <summary>Creates an unexpected EOF error with details.</summary>
    public static BcsException UnexpectedEof(int expected, int available)
        => new(BcsErrorType.UnexpectedEof, $"Unexpected end of input: expected {expected} bytes, got {available}");

    /// <summary>Creates an invalid boolean error.</summary>
    public static BcsException InvalidBoolean(byte value)
        => new(BcsErrorType.InvalidBoolean, $"Invalid boolean value: 0x{value:X2} (expected 0x00 or 0x01)");

    /// <summary>Creates an invalid option error.</summary>
    public static BcsException InvalidOption(byte value)
        => new(BcsErrorType.InvalidOption, $"Invalid option tag: 0x{value:X2} (expected 0x00 or 0x01)");

    /// <summary>Creates an invalid UTF-8 error.</summary>
    public static BcsException InvalidUtf8(string? reason = null)
        => new(BcsErrorType.InvalidUtf8, reason ?? "Invalid UTF-8 encoding");

    /// <summary>Creates a non-canonical ULEB128 error.</summary>
    public static BcsException NonCanonicalUleb128()
        => new(BcsErrorType.NonCanonicalUleb128, "Non-canonical ULEB128 encoding (trailing zero bytes)");

    /// <summary>Creates a ULEB128 overflow error.</summary>
    public static BcsException Uleb128Overflow()
        => new(BcsErrorType.Uleb128Overflow, "ULEB128 value overflow (exceeds u32 max)");

    /// <summary>Creates an exceeded max length error.</summary>
    public static BcsException ExceededMaxLength(ulong length)
        => new(BcsErrorType.ExceededMaxLength, $"Sequence length {length} exceeds maximum allowed (2^31 - 1)");

    /// <summary>Creates an exceeded container depth error.</summary>
    public static BcsException ExceededContainerDepth(string? container = null)
        => new(BcsErrorType.ExceededContainerDepth,
            string.IsNullOrEmpty(container)
                ? "Exceeded maximum container depth (500)"
                : $"Exceeded maximum container depth (500) while entering {container}");

    /// <summary>Creates a remaining input error.</summary>
    public static BcsException RemainingInput(int remaining)
        => new(BcsErrorType.RemainingInput, $"Remaining input after deserialization: {remaining} bytes");

    /// <summary>Creates a non-canonical map error.</summary>
    public static BcsException NonCanonicalMap(string? reason = null)
        => new(BcsErrorType.NonCanonicalMap, $"Non-canonical map: {reason ?? "keys not sorted or contain duplicates"}");

    /// <summary>Creates an unknown variant error.</summary>
    public static BcsException UnknownVariant(uint index, uint maxIndex)
        => new(BcsErrorType.UnknownVariant, $"Unknown enum variant index: {index} (max: {maxIndex})");

    /// <summary>Creates a not supported error.</summary>
    public static BcsException NotSupported(string typeName)
        => new(BcsErrorType.NotSupported, $"Type not supported: {typeName}");

    /// <summary>Creates a value out of range error.</summary>
    public static BcsException ValueOutOfRange(string typeName, object value)
        => new(BcsErrorType.ValueOutOfRange, $"{typeName} value out of range: {value}");
}
