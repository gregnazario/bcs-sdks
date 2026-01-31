// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#ifndef BCS_ULEB128_HPP
#define BCS_ULEB128_HPP

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <utility>
#include <vector>

#include "errors.hpp"

// Compiler hints for branch prediction
#if defined(__GNUC__) || defined(__clang__)
#define BCS_LIKELY(x) __builtin_expect(!!(x), 1)
#define BCS_UNLIKELY(x) __builtin_expect(!!(x), 0)
#define BCS_FORCE_INLINE __attribute__((always_inline)) inline
#else
#define BCS_LIKELY(x) (x)
#define BCS_UNLIKELY(x) (x)
#define BCS_FORCE_INLINE inline
#endif

namespace bcs {
namespace uleb128 {

/// Maximum value that can be encoded as ULEB128 in BCS (u32 max)
constexpr uint32_t MAX_VALUE = 0xFFFFFFFF;

/// Maximum number of bytes in a ULEB128-encoded u32
constexpr size_t MAX_BYTES = 5;

/// Small stack-allocated buffer for ULEB128 encoding
struct EncodedValue {
    uint8_t bytes[MAX_BYTES];
    uint8_t len;

    [[nodiscard]] const uint8_t* data() const noexcept { return bytes; }
    [[nodiscard]] const uint8_t* begin() const noexcept { return bytes; }
    [[nodiscard]] const uint8_t* end() const noexcept { return bytes + len; }
    [[nodiscard]] size_t size() const noexcept { return len; }
};

/// Calculate the encoded size of a value (constexpr for compile-time use)
/// @param value The value to calculate size for
/// @return Number of bytes required to encode the value
[[nodiscard]] constexpr size_t encoded_size(uint32_t value) noexcept {
    // Optimized using bit manipulation
    if (value < (1U << 7))
        return 1;
    if (value < (1U << 14))
        return 2;
    if (value < (1U << 21))
        return 3;
    if (value < (1U << 28))
        return 4;
    return 5;
}

/// Encode a 32-bit unsigned integer as ULEB128 into a stack buffer
/// @param value The value to encode
/// @return EncodedValue containing the ULEB128 encoding
[[nodiscard]] BCS_FORCE_INLINE EncodedValue
encode_to_buffer(uint32_t value) noexcept {
    EncodedValue result{};
    uint8_t i = 0;
    do {
        uint8_t byte = value & 0x7F;
        value >>= 7;
        if (value != 0) {
            byte |= 0x80;
        }
        result.bytes[i++] = byte;
    } while (value != 0);
    result.len = i;
    return result;
}

/// Encode a 32-bit unsigned integer as ULEB128
/// @param value The value to encode
/// @return Vector of bytes containing the ULEB128 encoding
[[nodiscard]] inline std::vector<uint8_t> encode(uint32_t value) {
    auto encoded = encode_to_buffer(value);
    return std::vector<uint8_t>(encoded.begin(), encoded.end());
}

/// Decode a ULEB128-encoded value from bytes
/// @param data Pointer to the start of the encoded data
/// @param size Number of bytes available
/// @return Pair of (decoded value, number of bytes consumed)
/// @throws Error on invalid encoding or overflow
BCS_FORCE_INLINE std::pair<uint32_t, size_t> decode(const uint8_t* data,
                                                    size_t size) {
    if (BCS_UNLIKELY(size == 0)) {
        throw Error::unexpected_eof();
    }

    // Fast path: single byte (values 0-127, very common for lengths)
    if (BCS_LIKELY((data[0] & 0x80) == 0)) {
        return {data[0], 1};
    }

    // Multi-byte path
    uint64_t value = 0;
    size_t shift = 0;
    const size_t max_bytes = (size < MAX_BYTES) ? size : MAX_BYTES;

    for (size_t i = 0; i < max_bytes; ++i) {
        const uint8_t byte = data[i];
        const uint8_t digit = byte & 0x7F;

        value |= static_cast<uint64_t>(digit) << shift;

        if ((byte & 0x80) == 0) {
            // Check for non-canonical encoding (trailing zeros)
            if (BCS_UNLIKELY(shift > 0 && digit == 0)) {
                throw Error::non_canonical_uleb128();
            }
            // Check for overflow
            if (BCS_UNLIKELY(value > MAX_VALUE)) {
                throw Error::uleb128_overflow();
            }
            return {static_cast<uint32_t>(value), i + 1};
        }
        shift += 7;
    }

    // If we've read MAX_BYTES and still have continuation bit, overflow
    if (max_bytes == MAX_BYTES) {
        throw Error::uleb128_overflow();
    }

    throw Error::unexpected_eof();
}

}  // namespace uleb128
}  // namespace bcs

#endif  // BCS_ULEB128_HPP
