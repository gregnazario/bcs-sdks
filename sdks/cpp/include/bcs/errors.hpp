// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#ifndef BCS_ERRORS_HPP
#define BCS_ERRORS_HPP

#include <cstdint>
#include <stdexcept>
#include <string>

namespace bcs {

/// Error types for BCS serialization/deserialization
enum class ErrorType {
    UnexpectedEof,
    InvalidBoolean,
    NonCanonicalUleb128,
    Uleb128Overflow,
    ExceededMaxLength,
    ExceededContainerDepth,
    InvalidUtf8,
    NonCanonicalMap,
    DuplicateMapKey,
    IntegerOutOfRange,
    RemainingInput,
    InvalidOption
};

/// Exception class for BCS errors
class Error : public std::runtime_error {
   public:
    Error(ErrorType type, const std::string& message)
        : std::runtime_error(message), type_(type) {}

    [[nodiscard]] ErrorType type() const noexcept { return type_; }

    // Static factory methods for common errors
    static Error unexpected_eof() {
        return Error(ErrorType::UnexpectedEof, "Unexpected end of input");
    }

    static Error invalid_boolean(uint8_t value) {
        return Error(ErrorType::InvalidBoolean,
                     "Invalid boolean value: " + std::to_string(value) +
                         " (expected 0 or 1)");
    }

    static Error non_canonical_uleb128() {
        return Error(ErrorType::NonCanonicalUleb128,
                     "ULEB128 encoding is not canonical (has trailing zeros)");
    }

    static Error uleb128_overflow() {
        return Error(ErrorType::Uleb128Overflow, "ULEB128 value overflows u32");
    }

    static Error exceeded_max_length(size_t length, size_t max_length) {
        return Error(ErrorType::ExceededMaxLength,
                     "Sequence length " + std::to_string(length) +
                         " exceeds maximum " + std::to_string(max_length));
    }

    static Error exceeded_container_depth(size_t depth) {
        return Error(ErrorType::ExceededContainerDepth,
                     "Container depth " + std::to_string(depth) +
                         " exceeds maximum allowed");
    }

    static Error invalid_utf8() {
        return Error(ErrorType::InvalidUtf8, "Invalid UTF-8 encoding");
    }

    static Error non_canonical_map() {
        return Error(ErrorType::NonCanonicalMap,
                     "Map keys are not in sorted order");
    }

    static Error duplicate_map_key() {
        return Error(ErrorType::DuplicateMapKey, "Duplicate key in map");
    }

    static Error integer_out_of_range(const std::string& type_name) {
        return Error(ErrorType::IntegerOutOfRange,
                     "Integer value out of range for " + type_name);
    }

    static Error remaining_input(size_t remaining) {
        return Error(ErrorType::RemainingInput,
                     "Input has " + std::to_string(remaining) +
                         " remaining bytes after deserialization");
    }

    static Error invalid_option(uint8_t value) {
        return Error(ErrorType::InvalidOption,
                     "Invalid option tag: " + std::to_string(value) +
                         " (expected 0 or 1)");
    }

   private:
    ErrorType type_;
};

}  // namespace bcs

#endif  // BCS_ERRORS_HPP
