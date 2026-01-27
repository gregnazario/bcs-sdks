// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#ifndef BCS_TYPES_HPP
#define BCS_TYPES_HPP

#include <array>
#include <cstdint>

namespace bcs {

/// Maximum length for variable-length sequences (2^31 - 1)
constexpr size_t MAX_SEQUENCE_LENGTH = (1ULL << 31) - 1;

/// Maximum container depth for nested structures
constexpr size_t MAX_CONTAINER_DEPTH = 500;

/// Integer bounds
constexpr uint8_t U8_MAX = 0xFF;
constexpr uint16_t U16_MAX = 0xFFFF;
constexpr uint32_t U32_MAX = 0xFFFFFFFF;
constexpr uint64_t U64_MAX = 0xFFFFFFFFFFFFFFFF;

constexpr int8_t I8_MIN = -128;
constexpr int8_t I8_MAX = 127;
constexpr int16_t I16_MIN = -32768;
constexpr int16_t I16_MAX = 32767;
constexpr int32_t I32_MIN = -2147483648;
constexpr int32_t I32_MAX = 2147483647;
constexpr int64_t I64_MIN = (-9223372036854775807LL - 1);
constexpr int64_t I64_MAX = 9223372036854775807LL;

/// 128-bit unsigned integer (as array of bytes, little-endian)
using u128 = std::array<uint8_t, 16>;

/// 256-bit unsigned integer (as array of bytes, little-endian)
using u256 = std::array<uint8_t, 32>;

/// 128-bit signed integer (as array of bytes, little-endian, two's complement)
using i128 = std::array<uint8_t, 16>;

/// 256-bit signed integer (as array of bytes, little-endian, two's complement)
using i256 = std::array<uint8_t, 32>;

}  // namespace bcs

#endif  // BCS_TYPES_HPP
