// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#ifndef BCS_SERIALIZER_HPP
#define BCS_SERIALIZER_HPP

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <functional>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "errors.hpp"
#include "types.hpp"
#include "uleb128.hpp"

namespace bcs {

/// @brief BCS Serializer -- manual serialization API.
///
/// Provides explicit methods for serializing each BCS type with method chaining.
///
/// @code
/// bcs::Serializer ser;
/// ser.write_u64(12345).write_string("hello").write_bool(true);
/// auto bytes = ser.to_bytes();
/// @endcode
class Serializer {
   public:
    /// Construct a new serializer with a default 256-byte buffer.
    Serializer() : depth_(0) { buffer_.reserve(256); }

    /// @brief Pre-allocate buffer capacity to reduce reallocations.
    /// @param capacity  Number of bytes to reserve.
    void reserve(size_t capacity) { buffer_.reserve(capacity); }

    /// @brief Serialize a boolean value (0x00 = false, 0x01 = true).
    /// @param value  Boolean to serialize.
    /// @return Reference to this serializer for chaining.
    Serializer& write_bool(bool value) {
        buffer_.push_back(value ? 1 : 0);
        return *this;
    }

    /// @brief Serialize an unsigned 8-bit integer.
    /// @param value  Value to serialize (0-255).
    Serializer& write_u8(uint8_t value) {
        buffer_.push_back(value);
        return *this;
    }

    /// @brief Serialize a signed 8-bit integer (two's complement).
    /// @param value  Value to serialize (-128 to 127).
    Serializer& write_i8(int8_t value) {
        buffer_.push_back(static_cast<uint8_t>(value));
        return *this;
    }

    /// @brief Serialize an unsigned 16-bit integer (little-endian).
    /// @param value  Value to serialize.
    Serializer& write_u16(uint16_t value) {
        // Reserve and write in bulk for better performance
        const size_t pos = buffer_.size();
        buffer_.resize(pos + 2);
        buffer_[pos] = static_cast<uint8_t>(value);
        buffer_[pos + 1] = static_cast<uint8_t>(value >> 8);
        return *this;
    }

    /// @brief Serialize a signed 16-bit integer (little-endian, two's complement).
    /// @param value  Value to serialize.
    Serializer& write_i16(int16_t value) {
        return write_u16(static_cast<uint16_t>(value));
    }

    /// @brief Serialize an unsigned 32-bit integer (little-endian).
    /// @param value  Value to serialize.
    Serializer& write_u32(uint32_t value) {
        // Reserve and write in bulk - unrolled for performance
        const size_t pos = buffer_.size();
        buffer_.resize(pos + 4);
        buffer_[pos] = static_cast<uint8_t>(value);
        buffer_[pos + 1] = static_cast<uint8_t>(value >> 8);
        buffer_[pos + 2] = static_cast<uint8_t>(value >> 16);
        buffer_[pos + 3] = static_cast<uint8_t>(value >> 24);
        return *this;
    }

    /// @brief Serialize a signed 32-bit integer (little-endian, two's complement).
    /// @param value  Value to serialize.
    Serializer& write_i32(int32_t value) {
        return write_u32(static_cast<uint32_t>(value));
    }

    /// @brief Serialize an unsigned 64-bit integer (little-endian).
    /// @param value  Value to serialize.
    Serializer& write_u64(uint64_t value) {
        // Reserve and write in bulk - unrolled for performance
        const size_t pos = buffer_.size();
        buffer_.resize(pos + 8);
        buffer_[pos] = static_cast<uint8_t>(value);
        buffer_[pos + 1] = static_cast<uint8_t>(value >> 8);
        buffer_[pos + 2] = static_cast<uint8_t>(value >> 16);
        buffer_[pos + 3] = static_cast<uint8_t>(value >> 24);
        buffer_[pos + 4] = static_cast<uint8_t>(value >> 32);
        buffer_[pos + 5] = static_cast<uint8_t>(value >> 40);
        buffer_[pos + 6] = static_cast<uint8_t>(value >> 48);
        buffer_[pos + 7] = static_cast<uint8_t>(value >> 56);
        return *this;
    }

    /// @brief Serialize a signed 64-bit integer (little-endian, two's complement).
    /// @param value  Value to serialize.
    Serializer& write_i64(int64_t value) {
        return write_u64(static_cast<uint64_t>(value));
    }

    /// @brief Serialize an unsigned 128-bit integer (little-endian byte array).
    /// @param value  16-byte array in little-endian order.
    Serializer& write_u128(const u128& value) {
        const size_t pos = buffer_.size();
        buffer_.resize(pos + 16);
        std::memcpy(buffer_.data() + pos, value.data(), 16);
        return *this;
    }

    /// @brief Serialize a signed 128-bit integer (little-endian byte array).
    /// @param value  16-byte array in little-endian two's complement.
    Serializer& write_i128(const i128& value) {
        const size_t pos = buffer_.size();
        buffer_.resize(pos + 16);
        std::memcpy(buffer_.data() + pos, value.data(), 16);
        return *this;
    }

    /// @brief Serialize an unsigned 256-bit integer (little-endian byte array).
    /// @param value  32-byte array in little-endian order.
    Serializer& write_u256(const u256& value) {
        const size_t pos = buffer_.size();
        buffer_.resize(pos + 32);
        std::memcpy(buffer_.data() + pos, value.data(), 32);
        return *this;
    }

    /// @brief Serialize a signed 256-bit integer (little-endian byte array).
    /// @param value  32-byte array in little-endian two's complement.
    Serializer& write_i256(const i256& value) {
        const size_t pos = buffer_.size();
        buffer_.resize(pos + 32);
        std::memcpy(buffer_.data() + pos, value.data(), 32);
        return *this;
    }

    /// @brief Serialize a ULEB128-encoded unsigned 32-bit integer.
    /// @param value  Value to encode (0 to 2^32-1).
    Serializer& write_uleb128(uint32_t value) {
        // Use stack-allocated buffer to avoid heap allocation
        auto encoded = uleb128::encode_to_buffer(value);
        // Use resize + memcpy instead of insert for better performance
        const size_t pos = buffer_.size();
        buffer_.resize(pos + encoded.size());
        std::memcpy(buffer_.data() + pos, encoded.data(), encoded.size());
        return *this;
    }

    /// @brief Serialize fixed-length raw bytes (no length prefix).
    /// @param data  Pointer to bytes.
    /// @param len   Number of bytes.
    Serializer& write_fixed_bytes(const uint8_t* data, size_t len) {
        const size_t pos = buffer_.size();
        buffer_.resize(pos + len);
        std::memcpy(buffer_.data() + pos, data, len);
        return *this;
    }

    /// @brief Serialize fixed-length raw bytes from a vector (no length prefix).
    /// @param data  Byte vector.
    Serializer& write_fixed_bytes(const std::vector<uint8_t>& data) {
        return write_fixed_bytes(data.data(), data.size());
    }

    /// @brief Serialize a byte array with ULEB128 length prefix.
    /// @param data  Pointer to bytes.
    /// @param len   Number of bytes.
    /// @throws bcs::Error if @p len exceeds MAX_SEQUENCE_LENGTH.
    Serializer& write_bytes(const uint8_t* data, size_t len) {
        check_sequence_length(len);
        // Pre-calculate total size needed with overflow check
        const size_t uleb_size =
            uleb128::encoded_size(static_cast<uint32_t>(len));
        const size_t current_size = buffer_.size();
        // Check for overflow before addition
        if (uleb_size > SIZE_MAX - len ||
            current_size > SIZE_MAX - uleb_size - len) {
            throw Error::exceeded_max_length(len, SIZE_MAX);
        }
        buffer_.reserve(current_size + uleb_size + len);
        write_uleb128(static_cast<uint32_t>(len));
        write_fixed_bytes(data, len);
        return *this;
    }

    /// @brief Serialize a byte vector with ULEB128 length prefix.
    /// @param data  Byte vector to serialize.
    /// @throws bcs::Error if data size exceeds MAX_SEQUENCE_LENGTH.
    Serializer& write_bytes(const std::vector<uint8_t>& data) {
        return write_bytes(data.data(), data.size());
    }

    /// @brief Serialize a UTF-8 string with ULEB128 length prefix.
    /// @param value  String view to serialize.
    /// @throws bcs::Error if string length exceeds MAX_SEQUENCE_LENGTH.
    Serializer& write_string(std::string_view value) {
        return write_bytes(reinterpret_cast<const uint8_t*>(value.data()),
                           value.size());
    }

    /// @brief Serialize an optional value (None = 0x00, Some = 0x01 + value).
    /// @tparam T     Type of the optional value.
    /// @tparam Func  Callable with signature void(Serializer&, const T&).
    /// @param opt         Optional value to serialize.
    /// @param serializer  Function to serialize the inner value if present.
    template <typename T, typename Func>
    Serializer& write_option(const std::optional<T>& opt, Func serializer) {
        if (opt.has_value()) {
            write_u8(1);
            serializer(*this, opt.value());
        } else {
            write_u8(0);
        }
        return *this;
    }

    /// @brief Serialize a vector with ULEB128 length prefix and per-element serializer.
    /// @tparam T     Element type.
    /// @tparam Func  Callable with signature void(Serializer&, const T&).
    /// @param vec         Vector to serialize.
    /// @param serializer  Function to serialize each element.
    /// @throws bcs::Error if vector size exceeds MAX_SEQUENCE_LENGTH.
    template <typename T, typename Func>
    Serializer& write_vector(const std::vector<T>& vec, Func serializer) {
        check_sequence_length(vec.size());
        write_uleb128(static_cast<uint32_t>(vec.size()));
        for (const auto& item : vec) {
            serializer(*this, item);
        }
        return *this;
    }

    /// @brief Serialize a map sorted by serialized key bytes.
    ///
    /// Keys are serialized, sorted lexicographically by their byte representation,
    /// then the sorted entries are written with ULEB128 length prefix.
    ///
    /// @tparam K          Key type.
    /// @tparam V          Value type.
    /// @tparam KeyFunc    Callable with signature void(Serializer&, const K&).
    /// @tparam ValueFunc  Callable with signature void(Serializer&, const V&).
    /// @param map               Map to serialize.
    /// @param key_serializer    Function to serialize keys.
    /// @param value_serializer  Function to serialize values.
    /// @throws bcs::Error if map size exceeds MAX_SEQUENCE_LENGTH.
    template <typename K, typename V, typename KeyFunc, typename ValueFunc>
    Serializer& write_map(const std::map<K, V>& map, KeyFunc key_serializer,
                          ValueFunc value_serializer) {
        check_sequence_length(map.size());

        // Serialize all entries and sort by key bytes
        // Use a single pair of reusable serializers to reduce allocations
        std::vector<std::pair<std::vector<uint8_t>, std::vector<uint8_t>>>
            entries;
        entries.reserve(map.size());

        Serializer temp_ser;  // Reuse single serializer
        for (const auto& [key, value] : map) {
            temp_ser.clear();
            key_serializer(temp_ser, key);
            auto key_bytes = temp_ser.to_bytes();

            temp_ser.clear();
            value_serializer(temp_ser, value);

            entries.emplace_back(std::move(key_bytes), temp_ser.to_bytes());
        }

        // Sort by key bytes (lexicographic)
        std::sort(
            entries.begin(), entries.end(),
            [](const auto& a, const auto& b) { return a.first < b.first; });

        // Write length and entries using efficient copy
        write_uleb128(static_cast<uint32_t>(entries.size()));
        for (const auto& [key_bytes, value_bytes] : entries) {
            write_fixed_bytes(key_bytes);
            write_fixed_bytes(value_bytes);
        }

        return *this;
    }

    /// @brief Serialize an enum variant index (ULEB128-encoded).
    /// @param index  Zero-based variant index.
    Serializer& write_variant_index(uint32_t index) {
        return write_uleb128(index);
    }

    /// @brief Enter a struct/enum container for depth tracking.
    /// @throws bcs::Error if container depth exceeds MAX_CONTAINER_DEPTH.
    Serializer& enter_container() {
        if (depth_ >= MAX_CONTAINER_DEPTH) {
            throw Error::exceeded_container_depth(depth_ + 1);
        }
        ++depth_;
        return *this;
    }

    /// @brief Leave a struct/enum container, decrementing depth.
    Serializer& leave_container() {
        --depth_;
        return *this;
    }

    /// @brief Get a copy of the serialized bytes.
    /// @return New vector containing the serialized data.
    [[nodiscard]] std::vector<uint8_t> to_bytes() const { return buffer_; }

    /// @brief Get a const reference to the internal buffer (zero-copy).
    /// @return Const reference to the serialized data.
    [[nodiscard]] const std::vector<uint8_t>& bytes() const { return buffer_; }

    /// @brief Get the current number of serialized bytes.
    [[nodiscard]] size_t size() const { return buffer_.size(); }

    /// @brief Clear the buffer and reset depth for reuse.
    void clear() {
        buffer_.clear();
        depth_ = 0;
    }

   private:
    void check_sequence_length(size_t len) {
        if (len > MAX_SEQUENCE_LENGTH) {
            throw Error::exceeded_max_length(len, MAX_SEQUENCE_LENGTH);
        }
    }

    std::vector<uint8_t> buffer_;
    size_t depth_;
};

}  // namespace bcs

#endif  // BCS_SERIALIZER_HPP
