// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#ifndef BCS_BCS_HPP
#define BCS_BCS_HPP

/// @file bcs.hpp
/// @brief Binary Canonical Serialization (BCS) - C++ Implementation
///
/// This is the main header file for the BCS C++ SDK. Include this file to get
/// access to all BCS functionality.
///
/// ## Quick Start
///
/// ```cpp
/// #include <bcs/bcs.hpp>
///
/// // Serialize
/// bcs::Serializer ser;
/// ser.write_u64(12345)
///    .write_string("hello")
///    .write_bool(true);
/// auto bytes = ser.to_bytes();
///
/// // Deserialize
/// bcs::Deserializer des(bytes);
/// uint64_t num = des.read_u64();
/// std::string str = des.read_string();
/// bool flag = des.read_bool();
/// des.check_end();  // Ensure all bytes consumed
/// ```
///
/// ## Supported Types
///
/// | Type      | Serializer Method  | Deserializer Method |
/// |-----------|-------------------|---------------------|
/// | bool      | write_bool()      | read_bool()         |
/// | uint8_t   | write_u8()        | read_u8()           |
/// | int8_t    | write_i8()        | read_i8()           |
/// | uint16_t  | write_u16()       | read_u16()          |
/// | int16_t   | write_i16()       | read_i16()          |
/// | uint32_t  | write_u32()       | read_u32()          |
/// | int32_t   | write_i32()       | read_i32()          |
/// | uint64_t  | write_u64()       | read_u64()          |
/// | int64_t   | write_i64()       | read_i64()          |
/// | u128      | write_u128()      | read_u128()         |
/// | i128      | write_i128()      | read_i128()         |
/// | u256      | write_u256()      | read_u256()         |
/// | i256      | write_i256()      | read_i256()         |
/// | string    | write_string()    | read_string()       |
/// | bytes     | write_bytes()     | read_bytes()        |
/// | optional  | write_option()    | read_option()       |
/// | vector    | write_vector()    | read_vector()       |
/// | map       | write_map()       | read_map()          |
///
/// ## Error Handling
///
/// All errors are reported via exceptions of type `bcs::Error`.
///
/// ```cpp
/// try {
///     bcs::Deserializer des(data);
///     auto value = des.read_u64();
/// } catch (const bcs::Error& e) {
///     std::cerr << "BCS error: " << e.what() << std::endl;
///     if (e.type() == bcs::ErrorType::UnexpectedEof) {
///         // Handle EOF specifically
///     }
/// }
/// ```

#include "deserializer.hpp"
#include "errors.hpp"
#include "serializer.hpp"
#include "types.hpp"
#include "uleb128.hpp"

namespace bcs {

// Convenience functions for single-value serialization

/// Serialize a u8 value
inline std::vector<uint8_t> serialize_u8(uint8_t value) {
    Serializer ser;
    ser.write_u8(value);
    return ser.to_bytes();
}

/// Serialize a u16 value
inline std::vector<uint8_t> serialize_u16(uint16_t value) {
    Serializer ser;
    ser.write_u16(value);
    return ser.to_bytes();
}

/// Serialize a u32 value
inline std::vector<uint8_t> serialize_u32(uint32_t value) {
    Serializer ser;
    ser.write_u32(value);
    return ser.to_bytes();
}

/// Serialize a u64 value
inline std::vector<uint8_t> serialize_u64(uint64_t value) {
    Serializer ser;
    ser.write_u64(value);
    return ser.to_bytes();
}

/// Serialize a bool value
inline std::vector<uint8_t> serialize_bool(bool value) {
    Serializer ser;
    ser.write_bool(value);
    return ser.to_bytes();
}

/// Serialize a string value
inline std::vector<uint8_t> serialize_string(const std::string& value) {
    Serializer ser;
    ser.write_string(value);
    return ser.to_bytes();
}

/// Deserialize a u8 value
inline uint8_t deserialize_u8(const std::vector<uint8_t>& data) {
    Deserializer des(data);
    uint8_t value = des.read_u8();
    des.check_end();
    return value;
}

/// Deserialize a u16 value
inline uint16_t deserialize_u16(const std::vector<uint8_t>& data) {
    Deserializer des(data);
    uint16_t value = des.read_u16();
    des.check_end();
    return value;
}

/// Deserialize a u32 value
inline uint32_t deserialize_u32(const std::vector<uint8_t>& data) {
    Deserializer des(data);
    uint32_t value = des.read_u32();
    des.check_end();
    return value;
}

/// Deserialize a u64 value
inline uint64_t deserialize_u64(const std::vector<uint8_t>& data) {
    Deserializer des(data);
    uint64_t value = des.read_u64();
    des.check_end();
    return value;
}

/// Deserialize a bool value
inline bool deserialize_bool(const std::vector<uint8_t>& data) {
    Deserializer des(data);
    bool value = des.read_bool();
    des.check_end();
    return value;
}

/// Deserialize a string value
inline std::string deserialize_string(const std::vector<uint8_t>& data) {
    Deserializer des(data);
    std::string value = des.read_string();
    des.check_end();
    return value;
}

}  // namespace bcs

#endif  // BCS_BCS_HPP
