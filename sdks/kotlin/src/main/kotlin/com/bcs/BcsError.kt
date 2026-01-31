/**
 * BCS Error types and exceptions
 */
package com.bcs

/**
 * Error types for BCS operations
 */
enum class BcsErrorType {
    UNEXPECTED_EOF,
    INVALID_BOOLEAN,
    NON_CANONICAL_ULEB128,
    ULEB128_OVERFLOW,
    EXCEEDED_MAX_LENGTH,
    EXCEEDED_CONTAINER_DEPTH,
    INVALID_UTF8,
    NON_CANONICAL_MAP,
    DUPLICATE_MAP_KEY,
    INTEGER_OUT_OF_RANGE,
    REMAINING_INPUT,
    INVALID_OPTION
}

/**
 * Exception thrown for BCS serialization/deserialization errors
 */
class BcsError(
    val type: BcsErrorType,
    override val message: String
) : RuntimeException(message) {

    companion object {
        fun unexpectedEof() = BcsError(
            BcsErrorType.UNEXPECTED_EOF,
            "Unexpected end of input"
        )

        fun invalidBoolean(value: Int) = BcsError(
            BcsErrorType.INVALID_BOOLEAN,
            "Invalid boolean value: $value (expected 0 or 1)"
        )

        fun nonCanonicalUleb128() = BcsError(
            BcsErrorType.NON_CANONICAL_ULEB128,
            "ULEB128 encoding is not canonical (has trailing zeros)"
        )

        fun uleb128Overflow() = BcsError(
            BcsErrorType.ULEB128_OVERFLOW,
            "ULEB128 value overflows u32"
        )

        fun exceededMaxLength(length: Int) = BcsError(
            BcsErrorType.EXCEEDED_MAX_LENGTH,
            "Sequence length $length exceeds maximum ${BcsConstants.MAX_SEQUENCE_LENGTH}"
        )

        fun exceededMaxLength(length: Long) = BcsError(
            BcsErrorType.EXCEEDED_MAX_LENGTH,
            "Sequence length $length exceeds maximum ${BcsConstants.MAX_SEQUENCE_LENGTH}"
        )

        fun exceededContainerDepth(container: String) = BcsError(
            BcsErrorType.EXCEEDED_CONTAINER_DEPTH,
            "Container depth exceeds maximum ${BcsConstants.MAX_CONTAINER_DEPTH}: $container"
        )

        fun invalidUtf8(message: String? = null) = BcsError(
            BcsErrorType.INVALID_UTF8,
            message ?: "Invalid UTF-8 encoding"
        )

        fun nonCanonicalMap(reason: String = "keys not sorted") = BcsError(
            BcsErrorType.NON_CANONICAL_MAP,
            "Non-canonical map: $reason"
        )

        fun duplicateMapKey() = BcsError(
            BcsErrorType.DUPLICATE_MAP_KEY,
            "Duplicate key in map"
        )

        fun integerOutOfRange(typeName: String) = BcsError(
            BcsErrorType.INTEGER_OUT_OF_RANGE,
            "Integer value out of range for $typeName"
        )

        fun remainingInput(remaining: Int) = BcsError(
            BcsErrorType.REMAINING_INPUT,
            "Input has $remaining remaining bytes after deserialization"
        )

        fun invalidOption(value: Int) = BcsError(
            BcsErrorType.INVALID_OPTION,
            "Invalid option tag: $value (expected 0 or 1)"
        )
    }
}
