// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#ifndef BCS_ULEB128_HPP
#define BCS_ULEB128_HPP

#include <cstddef>
#include <cstdint>
#include <utility>
#include <vector>

#include "errors.hpp"

namespace bcs {
namespace uleb128 {

/// Maximum value that can be encoded as ULEB128 in BCS (u32 max)
constexpr uint32_t MAX_VALUE = 0xFFFFFFFF;

/// Maximum number of bytes in a ULEB128-encoded u32
constexpr size_t MAX_BYTES = 5;

/// Encode a 32-bit unsigned integer as ULEB128
/// @param value The value to encode
/// @return Vector of bytes containing the ULEB128 encoding
inline std::vector<uint8_t> encode(uint32_t value) {
    std::vector<uint8_t> result;
    result.reserve(MAX_BYTES);

    do {
        uint8_t byte = value & 0x7F;
        value >>= 7;
        if (value != 0) {
            byte |= 0x80;  // Set continuation bit
        }
        result.push_back(byte);
    } while (value != 0);

    return result;
}

/// Decode a ULEB128-encoded value from bytes
/// @param data Pointer to the start of the encoded data
/// @param size Number of bytes available
/// @return Pair of (decoded value, number of bytes consumed)
/// @throws Error on invalid encoding or overflow
inline std::pair<uint32_t, size_t> decode(const uint8_t* data, size_t size) {
    uint64_t value = 0;
    size_t shift = 0;
    size_t bytes_read = 0;

    for (size_t i = 0; i < MAX_BYTES && i < size; ++i) {
        uint8_t byte = data[i];
        uint8_t digit = byte & 0x7F;

        value |= static_cast<uint64_t>(digit) << shift;
        bytes_read = i + 1;

        // Check if this is the last byte (high bit not set)
        if ((byte & 0x80) == 0) {
            // Check for non-canonical encoding (trailing zeros)
            if (shift > 0 && digit == 0) {
                throw Error::non_canonical_uleb128();
            }

            // Check for overflow
            if (value > MAX_VALUE) {
                throw Error::uleb128_overflow();
            }

            return {static_cast<uint32_t>(value), bytes_read};
        }

        shift += 7;
    }

    // If we've read MAX_BYTES and still have continuation bit, overflow
    if (bytes_read == MAX_BYTES) {
        throw Error::uleb128_overflow();
    }

    // Ran out of input
    throw Error::unexpected_eof();
}

/// Calculate the encoded size of a value
/// @param value The value to calculate size for
/// @return Number of bytes required to encode the value
inline size_t encoded_size(uint32_t value) {
    size_t size = 1;
    while (value >= 0x80) {
        value >>= 7;
        ++size;
    }
    return size;
}

}  // namespace uleb128
}  // namespace bcs

#endif  // BCS_ULEB128_HPP
