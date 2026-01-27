// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#ifndef BCS_DESERIALIZER_HPP
#define BCS_DESERIALIZER_HPP

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <functional>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "errors.hpp"
#include "types.hpp"
#include "uleb128.hpp"

namespace bcs {

/// BCS Deserializer - Manual deserialization API
class Deserializer {
   public:
    /// Construct from a byte vector
    explicit Deserializer(const std::vector<uint8_t>& data) noexcept
        : data_(data.data()), size_(data.size()), offset_(0), depth_(0) {}

    /// Construct from a raw byte pointer and size
    Deserializer(const uint8_t* data, size_t size) noexcept
        : data_(data), size_(size), offset_(0), depth_(0) {}

    /// Read a boolean value
    bool read_bool() {
        if (BCS_UNLIKELY(offset_ >= size_)) {
            throw Error::unexpected_eof();
        }
        const uint8_t byte = data_[offset_++];
        if (BCS_LIKELY(byte == 0)) {
            return false;
        } else if (BCS_LIKELY(byte == 1)) {
            return true;
        } else {
            throw Error::invalid_boolean(byte);
        }
    }

    /// Read an unsigned 8-bit integer
    uint8_t read_u8() {
        if (BCS_UNLIKELY(offset_ >= size_)) {
            throw Error::unexpected_eof();
        }
        return data_[offset_++];
    }

    /// Read a signed 8-bit integer
    int8_t read_i8() { return static_cast<int8_t>(read_u8()); }

    /// Read an unsigned 16-bit integer (little-endian)
    uint16_t read_u16() {
        if (BCS_UNLIKELY(offset_ + 2 > size_)) {
            throw Error::unexpected_eof();
        }
        const uint8_t* p = data_ + offset_;
        const uint16_t value = static_cast<uint16_t>(p[0]) |
                               (static_cast<uint16_t>(p[1]) << 8);
        offset_ += 2;
        return value;
    }

    /// Read a signed 16-bit integer (little-endian)
    int16_t read_i16() { return static_cast<int16_t>(read_u16()); }

    /// Read an unsigned 32-bit integer (little-endian)
    uint32_t read_u32() {
        if (BCS_UNLIKELY(offset_ + 4 > size_)) {
            throw Error::unexpected_eof();
        }
        const uint8_t* p = data_ + offset_;
        const uint32_t value = static_cast<uint32_t>(p[0]) |
                               (static_cast<uint32_t>(p[1]) << 8) |
                               (static_cast<uint32_t>(p[2]) << 16) |
                               (static_cast<uint32_t>(p[3]) << 24);
        offset_ += 4;
        return value;
    }

    /// Read a signed 32-bit integer (little-endian)
    int32_t read_i32() { return static_cast<int32_t>(read_u32()); }

    /// Read an unsigned 64-bit integer (little-endian)
    uint64_t read_u64() {
        if (BCS_UNLIKELY(offset_ + 8 > size_)) {
            throw Error::unexpected_eof();
        }
        // Unrolled for performance
        const uint8_t* p = data_ + offset_;
        const uint64_t value = static_cast<uint64_t>(p[0]) |
                               (static_cast<uint64_t>(p[1]) << 8) |
                               (static_cast<uint64_t>(p[2]) << 16) |
                               (static_cast<uint64_t>(p[3]) << 24) |
                               (static_cast<uint64_t>(p[4]) << 32) |
                               (static_cast<uint64_t>(p[5]) << 40) |
                               (static_cast<uint64_t>(p[6]) << 48) |
                               (static_cast<uint64_t>(p[7]) << 56);
        offset_ += 8;
        return value;
    }

    /// Read a signed 64-bit integer (little-endian)
    int64_t read_i64() { return static_cast<int64_t>(read_u64()); }

    /// Read an unsigned 128-bit integer (little-endian byte array)
    u128 read_u128() {
        if (BCS_UNLIKELY(offset_ + 16 > size_)) {
            throw Error::unexpected_eof();
        }
        u128 value;
        std::memcpy(value.data(), data_ + offset_, 16);
        offset_ += 16;
        return value;
    }

    /// Read a signed 128-bit integer (little-endian byte array)
    i128 read_i128() {
        if (BCS_UNLIKELY(offset_ + 16 > size_)) {
            throw Error::unexpected_eof();
        }
        i128 value;
        std::memcpy(value.data(), data_ + offset_, 16);
        offset_ += 16;
        return value;
    }

    /// Read an unsigned 256-bit integer (little-endian byte array)
    u256 read_u256() {
        if (BCS_UNLIKELY(offset_ + 32 > size_)) {
            throw Error::unexpected_eof();
        }
        u256 value;
        std::memcpy(value.data(), data_ + offset_, 32);
        offset_ += 32;
        return value;
    }

    /// Read a signed 256-bit integer (little-endian byte array)
    i256 read_i256() {
        if (BCS_UNLIKELY(offset_ + 32 > size_)) {
            throw Error::unexpected_eof();
        }
        i256 value;
        std::memcpy(value.data(), data_ + offset_, 32);
        offset_ += 32;
        return value;
    }

    /// Read a ULEB128-encoded value
    uint32_t read_uleb128() {
        auto [value, bytes_read] =
            uleb128::decode(data_ + offset_, size_ - offset_);
        offset_ += bytes_read;
        return value;
    }

    /// Read fixed-length bytes (without length prefix)
    std::vector<uint8_t> read_fixed_bytes(size_t len) {
        if (BCS_UNLIKELY(offset_ + len > size_)) {
            throw Error::unexpected_eof();
        }
        std::vector<uint8_t> result(len);
        std::memcpy(result.data(), data_ + offset_, len);
        offset_ += len;
        return result;
    }

    /// Read fixed-length bytes into a provided buffer
    void read_fixed_bytes_into(uint8_t* buffer, size_t len) {
        if (BCS_UNLIKELY(offset_ + len > size_)) {
            throw Error::unexpected_eof();
        }
        std::memcpy(buffer, data_ + offset_, len);
        offset_ += len;
    }

    /// Read bytes with ULEB128 length prefix
    std::vector<uint8_t> read_bytes() {
        const uint32_t len = read_uleb128();
        check_sequence_length(len);
        return read_fixed_bytes(len);
    }

    /// Read a UTF-8 string with ULEB128 length prefix
    std::string read_string() {
        const uint32_t len = read_uleb128();
        check_sequence_length(len);
        if (BCS_UNLIKELY(offset_ + len > size_)) {
            throw Error::unexpected_eof();
        }
        // Validate UTF-8 before copying
        if (BCS_UNLIKELY(!is_valid_utf8(data_ + offset_, len))) {
            throw Error::invalid_utf8();
        }
        std::string result(reinterpret_cast<const char*>(data_ + offset_), len);
        offset_ += len;
        return result;
    }

    /// Read an optional value
    template <typename T, typename Func>
    std::optional<T> read_option(Func deserializer) {
        if (BCS_UNLIKELY(offset_ >= size_)) {
            throw Error::unexpected_eof();
        }
        const uint8_t tag = data_[offset_++];
        if (BCS_LIKELY(tag == 0)) {
            return std::nullopt;
        } else if (BCS_LIKELY(tag == 1)) {
            return deserializer(*this);
        } else {
            throw Error::invalid_option(tag);
        }
    }

    /// Read a vector with element deserializer
    template <typename T, typename Func>
    std::vector<T> read_vector(Func deserializer) {
        const uint32_t len = read_uleb128();
        check_sequence_length(len);

        std::vector<T> result;
        result.reserve(len);
        for (uint32_t i = 0; i < len; ++i) {
            result.push_back(deserializer(*this));
        }
        return result;
    }

    /// Read a map with key/value deserializers
    template <typename K, typename V, typename KeyFunc, typename ValueFunc>
    std::map<K, V> read_map(KeyFunc key_deserializer,
                            ValueFunc value_deserializer) {
        const uint32_t len = read_uleb128();
        check_sequence_length(len);

        std::map<K, V> result;
        std::vector<uint8_t> prev_key_bytes;

        for (uint32_t i = 0; i < len; ++i) {
            // Remember position before reading key
            const size_t key_start = offset_;

            K key = key_deserializer(*this);

            // Get key bytes for ordering check
            std::vector<uint8_t> key_bytes(data_ + key_start, data_ + offset_);

            // Check ordering
            if (i > 0) {
                if (key_bytes <= prev_key_bytes) {
                    if (key_bytes == prev_key_bytes) {
                        throw Error::duplicate_map_key();
                    }
                    throw Error::non_canonical_map();
                }
            }
            prev_key_bytes = std::move(key_bytes);

            V value = value_deserializer(*this);
            result.emplace(std::move(key), std::move(value));
        }

        return result;
    }

    /// Read an enum variant index
    uint32_t read_variant_index() { return read_uleb128(); }

    /// Enter a struct/enum container (for depth tracking)
    Deserializer& enter_container() {
        ++depth_;
        if (BCS_UNLIKELY(depth_ > MAX_CONTAINER_DEPTH)) {
            throw Error::exceeded_container_depth(depth_);
        }
        return *this;
    }

    /// Leave a struct/enum container
    Deserializer& leave_container() noexcept {
        --depth_;
        return *this;
    }

    /// Check that all input has been consumed
    void check_end() {
        if (BCS_UNLIKELY(offset_ < size_)) {
            throw Error::remaining_input(size_ - offset_);
        }
    }

    /// Get the current offset
    [[nodiscard]] size_t offset() const noexcept { return offset_; }

    /// Get the remaining bytes count
    [[nodiscard]] size_t remaining() const noexcept { return size_ - offset_; }

    /// Check if there's more data to read
    [[nodiscard]] bool has_remaining() const noexcept { return offset_ < size_; }

   private:
    void check_sequence_length(uint32_t len) {
        if (BCS_UNLIKELY(len > MAX_SEQUENCE_LENGTH)) {
            throw Error::exceeded_max_length(len, MAX_SEQUENCE_LENGTH);
        }
    }

    /// Optimized UTF-8 validation with ASCII fast path
    static bool is_valid_utf8(const uint8_t* data, size_t len) noexcept {
        size_t i = 0;

        // Fast path: scan for ASCII-only content (very common case)
        // Process 8 bytes at a time when possible
        while (i + 8 <= len) {
            uint64_t chunk;
            std::memcpy(&chunk, data + i, 8);
            // Check if any byte has high bit set
            if ((chunk & 0x8080808080808080ULL) == 0) {
                i += 8;
                continue;
            }
            break;
        }

        // Handle remaining bytes (including non-ASCII)
        while (i < len) {
            const uint8_t c = data[i];

            // ASCII fast path
            if (BCS_LIKELY((c & 0x80) == 0)) {
                ++i;
                continue;
            }

            size_t char_len;
            if ((c & 0xE0) == 0xC0) {
                char_len = 2;
                if (BCS_UNLIKELY(c < 0xC2))
                    return false;  // Overlong encoding
            } else if ((c & 0xF0) == 0xE0) {
                char_len = 3;
            } else if ((c & 0xF8) == 0xF0) {
                char_len = 4;
                if (BCS_UNLIKELY(c > 0xF4))
                    return false;  // Invalid
            } else {
                return false;  // Invalid start byte
            }

            if (BCS_UNLIKELY(i + char_len > len)) {
                return false;  // Incomplete sequence
            }

            // Validate continuation bytes
            for (size_t j = 1; j < char_len; ++j) {
                if (BCS_UNLIKELY((data[i + j] & 0xC0) != 0x80)) {
                    return false;
                }
            }

            // Check for overlong encodings and invalid code points
            if (char_len == 3) {
                const uint32_t code_point = ((c & 0x0F) << 12) |
                                            ((data[i + 1] & 0x3F) << 6) |
                                            (data[i + 2] & 0x3F);
                if (BCS_UNLIKELY(code_point < 0x0800))
                    return false;  // Overlong
                if (BCS_UNLIKELY(code_point >= 0xD800 && code_point <= 0xDFFF))
                    return false;  // Surrogates
            } else if (char_len == 4) {
                const uint32_t code_point =
                    ((c & 0x07) << 18) | ((data[i + 1] & 0x3F) << 12) |
                    ((data[i + 2] & 0x3F) << 6) | (data[i + 3] & 0x3F);
                if (BCS_UNLIKELY(code_point < 0x10000 || code_point > 0x10FFFF))
                    return false;
            }

            i += char_len;
        }
        return true;
    }

    const uint8_t* data_;
    size_t size_;
    size_t offset_;
    size_t depth_;
};

}  // namespace bcs

#endif  // BCS_DESERIALIZER_HPP
