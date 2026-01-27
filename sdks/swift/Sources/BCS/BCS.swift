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
    @inlinable
    public static func serializeU8(_ value: UInt8) -> [UInt8] {
        [value]
    }

    /// Serialize a UInt16 value
    @inlinable
    public static func serializeU16(_ value: UInt16) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value &>> 8)]
    }

    /// Serialize a UInt32 value
    @inlinable
    public static func serializeU32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value &>> 8),
            UInt8(truncatingIfNeeded: value &>> 16),
            UInt8(truncatingIfNeeded: value &>> 24),
        ]
    }

    /// Serialize a UInt64 value
    @inlinable
    public static func serializeU64(_ value: UInt64) -> [UInt8] {
        [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value &>> 8),
            UInt8(truncatingIfNeeded: value &>> 16),
            UInt8(truncatingIfNeeded: value &>> 24),
            UInt8(truncatingIfNeeded: value &>> 32),
            UInt8(truncatingIfNeeded: value &>> 40),
            UInt8(truncatingIfNeeded: value &>> 48),
            UInt8(truncatingIfNeeded: value &>> 56),
        ]
    }

    /// Serialize a Bool value
    @inlinable
    public static func serializeBool(_ value: Bool) -> [UInt8] {
        [value ? 1 : 0]
    }

    /// Serialize a String value
    @inlinable
    public static func serializeString(_ value: String) throws -> [UInt8] {
        try BcsSerializer().writeString(value).toBytes()
    }

    /// Serialize bytes
    @inlinable
    public static func serializeBytes(_ value: [UInt8]) throws -> [UInt8] {
        try BcsSerializer().writeBytes(value).toBytes()
    }

    // MARK: - Convenience Deserialization Functions

    /// Deserialize a UInt8 value
    @inlinable
    public static func deserializeU8(_ data: [UInt8]) throws -> UInt8 {
        guard data.count == 1 else {
            if data.isEmpty {
                throw BcsError.unexpectedEof()
            }
            throw BcsError.remainingInput(data.count - 1)
        }
        return data[0]
    }

    /// Deserialize a UInt16 value
    @inlinable
    public static func deserializeU16(_ data: [UInt8]) throws -> UInt16 {
        guard data.count == 2 else {
            if data.count < 2 {
                throw BcsError.unexpectedEof()
            }
            throw BcsError.remainingInput(data.count - 2)
        }
        return UInt16(data[0]) | (UInt16(data[1]) &<< 8)
    }

    /// Deserialize a UInt32 value
    @inlinable
    public static func deserializeU32(_ data: [UInt8]) throws -> UInt32 {
        guard data.count == 4 else {
            if data.count < 4 {
                throw BcsError.unexpectedEof()
            }
            throw BcsError.remainingInput(data.count - 4)
        }
        return UInt32(data[0])
            | (UInt32(data[1]) &<< 8)
            | (UInt32(data[2]) &<< 16)
            | (UInt32(data[3]) &<< 24)
    }

    /// Deserialize a UInt64 value
    @inlinable
    public static func deserializeU64(_ data: [UInt8]) throws -> UInt64 {
        guard data.count == 8 else {
            if data.count < 8 {
                throw BcsError.unexpectedEof()
            }
            throw BcsError.remainingInput(data.count - 8)
        }
        return UInt64(data[0])
            | (UInt64(data[1]) &<< 8)
            | (UInt64(data[2]) &<< 16)
            | (UInt64(data[3]) &<< 24)
            | (UInt64(data[4]) &<< 32)
            | (UInt64(data[5]) &<< 40)
            | (UInt64(data[6]) &<< 48)
            | (UInt64(data[7]) &<< 56)
    }

    /// Deserialize a Bool value
    @inlinable
    public static func deserializeBool(_ data: [UInt8]) throws -> Bool {
        guard data.count == 1 else {
            if data.isEmpty {
                throw BcsError.unexpectedEof()
            }
            throw BcsError.remainingInput(data.count - 1)
        }
        switch data[0] {
        case 0: return false
        case 1: return true
        default: throw BcsError.invalidBoolean(data[0])
        }
    }

    /// Deserialize a String value
    @inlinable
    public static func deserializeString(_ data: [UInt8]) throws -> String {
        let des = BcsDeserializer(data)
        let value = try des.readString()
        try des.checkEnd()
        return value
    }

    /// Deserialize bytes
    @inlinable
    public static func deserializeBytes(_ data: [UInt8]) throws -> [UInt8] {
        let des = BcsDeserializer(data)
        let value = try des.readBytes()
        try des.checkEnd()
        return value
    }

    // MARK: - Hex Utilities

    /// Hex lookup table for fast conversion
    @usableFromInline
    internal static let hexChars: [UInt8] = Array("0123456789abcdef".utf8)

    /// Convert bytes to hex string
    @inlinable
    public static func bytesToHex(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else { return "" }

        var hexBytes = [UInt8](repeating: 0, count: bytes.count * 2)
        for (i, byte) in bytes.enumerated() {
            hexBytes[i * 2] = hexChars[Int(byte >> 4)]
            hexBytes[i * 2 + 1] = hexChars[Int(byte & 0x0F)]
        }
        return String(decoding: hexBytes, as: UTF8.self)
    }

    /// Convert hex string to bytes
    @inlinable
    public static func hexToBytes(_ hex: String) -> [UInt8]? {
        let utf8 = Array(hex.utf8)
        guard utf8.count % 2 == 0 else { return nil }
        guard utf8.count > 0 else { return [] }

        var result = [UInt8](repeating: 0, count: utf8.count / 2)

        for i in 0..<result.count {
            guard let high = hexDigitValue(utf8[i * 2]),
                  let low = hexDigitValue(utf8[i * 2 + 1]) else {
                return nil
            }
            result[i] = (high << 4) | low
        }

        return result
    }

    /// Convert a hex character (ASCII) to its numeric value
    @usableFromInline
    internal static func hexDigitValue(_ char: UInt8) -> UInt8? {
        switch char {
        case 0x30...0x39:  // '0'-'9'
            return char - 0x30
        case 0x41...0x46:  // 'A'-'F'
            return char - 0x41 + 10
        case 0x61...0x66:  // 'a'-'f'
            return char - 0x61 + 10
        default:
            return nil
        }
    }
}
