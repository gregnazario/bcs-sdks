// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Binary Canonical Serialization (BCS) - Swift Implementation
///
/// BCS is a deterministic binary serialization format designed for
/// canonical representation of data structures.
///
/// ## Quick Start
///
/// ```swift
/// // Serialize
/// let ser = BcsSerializer()
/// ser.writeU64(12345)
///    .writeString("hello")
///    .writeBool(true)
/// let bytes = ser.toBytes()
///
/// // Deserialize
/// let des = BcsDeserializer(bytes)
/// let num = try des.readU64()
/// let str = try des.readString()
/// let flag = try des.readBool()
/// try des.checkEnd()
/// ```
public enum BCS {
    // MARK: - Convenience Serialization Functions

    /// Serialize a UInt8 value
    public static func serializeU8(_ value: UInt8) -> [UInt8] {
        BcsSerializer().writeU8(value).toBytes()
    }

    /// Serialize a UInt16 value
    public static func serializeU16(_ value: UInt16) -> [UInt8] {
        BcsSerializer().writeU16(value).toBytes()
    }

    /// Serialize a UInt32 value
    public static func serializeU32(_ value: UInt32) -> [UInt8] {
        BcsSerializer().writeU32(value).toBytes()
    }

    /// Serialize a UInt64 value
    public static func serializeU64(_ value: UInt64) -> [UInt8] {
        BcsSerializer().writeU64(value).toBytes()
    }

    /// Serialize a Bool value
    public static func serializeBool(_ value: Bool) -> [UInt8] {
        BcsSerializer().writeBool(value).toBytes()
    }

    /// Serialize a String value
    public static func serializeString(_ value: String) throws -> [UInt8] {
        try BcsSerializer().writeString(value).toBytes()
    }

    /// Serialize bytes
    public static func serializeBytes(_ value: [UInt8]) throws -> [UInt8] {
        try BcsSerializer().writeBytes(value).toBytes()
    }

    // MARK: - Convenience Deserialization Functions

    /// Deserialize a UInt8 value
    public static func deserializeU8(_ data: [UInt8]) throws -> UInt8 {
        let des = BcsDeserializer(data)
        let value = try des.readU8()
        try des.checkEnd()
        return value
    }

    /// Deserialize a UInt16 value
    public static func deserializeU16(_ data: [UInt8]) throws -> UInt16 {
        let des = BcsDeserializer(data)
        let value = try des.readU16()
        try des.checkEnd()
        return value
    }

    /// Deserialize a UInt32 value
    public static func deserializeU32(_ data: [UInt8]) throws -> UInt32 {
        let des = BcsDeserializer(data)
        let value = try des.readU32()
        try des.checkEnd()
        return value
    }

    /// Deserialize a UInt64 value
    public static func deserializeU64(_ data: [UInt8]) throws -> UInt64 {
        let des = BcsDeserializer(data)
        let value = try des.readU64()
        try des.checkEnd()
        return value
    }

    /// Deserialize a Bool value
    public static func deserializeBool(_ data: [UInt8]) throws -> Bool {
        let des = BcsDeserializer(data)
        let value = try des.readBool()
        try des.checkEnd()
        return value
    }

    /// Deserialize a String value
    public static func deserializeString(_ data: [UInt8]) throws -> String {
        let des = BcsDeserializer(data)
        let value = try des.readString()
        try des.checkEnd()
        return value
    }

    /// Deserialize bytes
    public static func deserializeBytes(_ data: [UInt8]) throws -> [UInt8] {
        let des = BcsDeserializer(data)
        let value = try des.readBytes()
        try des.checkEnd()
        return value
    }

    // MARK: - Hex Utilities

    /// Convert bytes to hex string
    public static func bytesToHex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Convert hex string to bytes
    public static func hexToBytes(_ hex: String) -> [UInt8]? {
        var result: [UInt8] = []
        var index = hex.startIndex

        while index < hex.endIndex {
            guard let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) else {
                return nil
            }
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            result.append(byte)
            index = nextIndex
        }

        return result
    }
}
