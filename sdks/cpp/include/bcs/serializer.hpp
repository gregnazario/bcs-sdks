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

/// BCS Serializer - Manual serialization API
class Serializer {
   public:
    Serializer() : depth_(0) { buffer_.reserve(256); }

    /// Write a boolean value
    Serializer& write_bool(bool value) {
        buffer_.push_back(value ? 1 : 0);
        return *this;
    }

    /// Write an unsigned 8-bit integer
    Serializer& write_u8(uint8_t value) {
        buffer_.push_back(value);
        return *this;
    }

    /// Write a signed 8-bit integer
    Serializer& write_i8(int8_t value) {
        buffer_.push_back(static_cast<uint8_t>(value));
        return *this;
    }

    /// Write an unsigned 16-bit integer (little-endian)
    Serializer& write_u16(uint16_t value) {
        buffer_.push_back(static_cast<uint8_t>(value & 0xFF));
        buffer_.push_back(static_cast<uint8_t>((value >> 8) & 0xFF));
        return *this;
    }

    /// Write a signed 16-bit integer (little-endian)
    Serializer& write_i16(int16_t value) {
        return write_u16(static_cast<uint16_t>(value));
    }

    /// Write an unsigned 32-bit integer (little-endian)
    Serializer& write_u32(uint32_t value) {
        buffer_.push_back(static_cast<uint8_t>(value & 0xFF));
        buffer_.push_back(static_cast<uint8_t>((value >> 8) & 0xFF));
        buffer_.push_back(static_cast<uint8_t>((value >> 16) & 0xFF));
        buffer_.push_back(static_cast<uint8_t>((value >> 24) & 0xFF));
        return *this;
    }

    /// Write a signed 32-bit integer (little-endian)
    Serializer& write_i32(int32_t value) {
        return write_u32(static_cast<uint32_t>(value));
    }

    /// Write an unsigned 64-bit integer (little-endian)
    Serializer& write_u64(uint64_t value) {
        for (int i = 0; i < 8; ++i) {
            buffer_.push_back(static_cast<uint8_t>((value >> (i * 8)) & 0xFF));
        }
        return *this;
    }

    /// Write a signed 64-bit integer (little-endian)
    Serializer& write_i64(int64_t value) {
        return write_u64(static_cast<uint64_t>(value));
    }

    /// Write an unsigned 128-bit integer (little-endian byte array)
    Serializer& write_u128(const u128& value) {
        buffer_.insert(buffer_.end(), value.begin(), value.end());
        return *this;
    }

    /// Write a signed 128-bit integer (little-endian byte array)
    Serializer& write_i128(const i128& value) {
        buffer_.insert(buffer_.end(), value.begin(), value.end());
        return *this;
    }

    /// Write an unsigned 256-bit integer (little-endian byte array)
    Serializer& write_u256(const u256& value) {
        buffer_.insert(buffer_.end(), value.begin(), value.end());
        return *this;
    }

    /// Write a signed 256-bit integer (little-endian byte array)
    Serializer& write_i256(const i256& value) {
        buffer_.insert(buffer_.end(), value.begin(), value.end());
        return *this;
    }

    /// Write a ULEB128-encoded length
    Serializer& write_uleb128(uint32_t value) {
        auto encoded = uleb128::encode(value);
        buffer_.insert(buffer_.end(), encoded.begin(), encoded.end());
        return *this;
    }

    /// Write raw bytes (without length prefix)
    Serializer& write_fixed_bytes(const uint8_t* data, size_t len) {
        buffer_.insert(buffer_.end(), data, data + len);
        return *this;
    }

    /// Write raw bytes (without length prefix) from vector
    Serializer& write_fixed_bytes(const std::vector<uint8_t>& data) {
        buffer_.insert(buffer_.end(), data.begin(), data.end());
        return *this;
    }

    /// Write bytes with ULEB128 length prefix
    Serializer& write_bytes(const uint8_t* data, size_t len) {
        check_sequence_length(len);
        write_uleb128(static_cast<uint32_t>(len));
        buffer_.insert(buffer_.end(), data, data + len);
        return *this;
    }

    /// Write bytes with ULEB128 length prefix from vector
    Serializer& write_bytes(const std::vector<uint8_t>& data) {
        return write_bytes(data.data(), data.size());
    }

    /// Write a UTF-8 string with ULEB128 length prefix
    Serializer& write_string(std::string_view value) {
        return write_bytes(reinterpret_cast<const uint8_t*>(value.data()),
                           value.size());
    }

    /// Write an optional value
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

    /// Write a vector with element serializer
    template <typename T, typename Func>
    Serializer& write_vector(const std::vector<T>& vec, Func serializer) {
        check_sequence_length(vec.size());
        write_uleb128(static_cast<uint32_t>(vec.size()));
        for (const auto& item : vec) {
            serializer(*this, item);
        }
        return *this;
    }

    /// Write a map with key/value serializers (sorted by serialized key bytes)
    template <typename K, typename V, typename KeyFunc, typename ValueFunc>
    Serializer& write_map(const std::map<K, V>& map, KeyFunc key_serializer,
                          ValueFunc value_serializer) {
        check_sequence_length(map.size());

        // Serialize all entries and sort by key bytes
        std::vector<std::pair<std::vector<uint8_t>, std::vector<uint8_t>>>
            entries;
        entries.reserve(map.size());

        for (const auto& [key, value] : map) {
            Serializer key_ser;
            key_serializer(key_ser, key);

            Serializer value_ser;
            value_serializer(value_ser, value);

            entries.emplace_back(key_ser.to_bytes(), value_ser.to_bytes());
        }

        // Sort by key bytes (lexicographic)
        std::sort(
            entries.begin(), entries.end(),
            [](const auto& a, const auto& b) { return a.first < b.first; });

        // Write length and entries
        write_uleb128(static_cast<uint32_t>(entries.size()));
        for (const auto& [key_bytes, value_bytes] : entries) {
            buffer_.insert(buffer_.end(), key_bytes.begin(), key_bytes.end());
            buffer_.insert(buffer_.end(), value_bytes.begin(),
                           value_bytes.end());
        }

        return *this;
    }

    /// Write an enum variant index
    Serializer& write_variant_index(uint32_t index) {
        return write_uleb128(index);
    }

    /// Enter a struct/enum container (for depth tracking)
    Serializer& enter_container() {
        ++depth_;
        if (depth_ > MAX_CONTAINER_DEPTH) {
            throw Error::exceeded_container_depth(depth_);
        }
        return *this;
    }

    /// Leave a struct/enum container
    Serializer& leave_container() {
        --depth_;
        return *this;
    }

    /// Get the serialized bytes
    [[nodiscard]] std::vector<uint8_t> to_bytes() const { return buffer_; }

    /// Get a view of the serialized bytes
    [[nodiscard]] const std::vector<uint8_t>& bytes() const { return buffer_; }

    /// Get the current size of the buffer
    [[nodiscard]] size_t size() const { return buffer_.size(); }

    /// Clear the buffer
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
