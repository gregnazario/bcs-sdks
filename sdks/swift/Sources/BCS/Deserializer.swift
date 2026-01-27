// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// BCS Deserializer - Manual deserialization API
public final class BcsDeserializer {
    private let data: [UInt8]
    private var offset: Int = 0
    private var depth: Int = 0

    /// Create a deserializer from a byte array
    public init(_ data: [UInt8]) {
        self.data = data
    }

    /// Create a deserializer from Data
    public init(_ data: Data) {
        self.data = Array(data)
    }

    // MARK: - Boolean

    /// Read a boolean value
    public func readBool() throws -> Bool {
        let byte = try readU8()
        switch byte {
        case 0: return false
        case 1: return true
        default: throw BcsError.invalidBoolean(byte)
        }
    }

    // MARK: - Unsigned Integers

    /// Read an unsigned 8-bit integer
    public func readU8() throws -> UInt8 {
        try checkRemaining(1)
        let value = data[offset]
        offset += 1
        return value
    }

    /// Read an unsigned 16-bit integer (little-endian)
    public func readU16() throws -> UInt16 {
        try checkRemaining(2)
        let value = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        offset += 2
        return value
    }

    /// Read an unsigned 32-bit integer (little-endian)
    public func readU32() throws -> UInt32 {
        try checkRemaining(4)
        var value: UInt32 = 0
        for i in 0..<4 {
            value |= UInt32(data[offset + i]) << (i * 8)
        }
        offset += 4
        return value
    }

    /// Read an unsigned 64-bit integer (little-endian)
    public func readU64() throws -> UInt64 {
        try checkRemaining(8)
        var value: UInt64 = 0
        for i in 0..<8 {
            value |= UInt64(data[offset + i]) << (i * 8)
        }
        offset += 8
        return value
    }

    /// Read an unsigned 128-bit integer (little-endian byte array)
    public func readU128() throws -> [UInt8] {
        try readFixedBytes(16)
    }

    /// Read an unsigned 256-bit integer (little-endian byte array)
    public func readU256() throws -> [UInt8] {
        try readFixedBytes(32)
    }

    // MARK: - Signed Integers

    /// Read a signed 8-bit integer
    public func readI8() throws -> Int8 {
        Int8(bitPattern: try readU8())
    }

    /// Read a signed 16-bit integer (little-endian)
    public func readI16() throws -> Int16 {
        Int16(bitPattern: try readU16())
    }

    /// Read a signed 32-bit integer (little-endian)
    public func readI32() throws -> Int32 {
        Int32(bitPattern: try readU32())
    }

    /// Read a signed 64-bit integer (little-endian)
    public func readI64() throws -> Int64 {
        Int64(bitPattern: try readU64())
    }

    /// Read a signed 128-bit integer (little-endian byte array)
    public func readI128() throws -> [UInt8] {
        try readU128()
    }

    /// Read a signed 256-bit integer (little-endian byte array)
    public func readI256() throws -> [UInt8] {
        try readU256()
    }

    // MARK: - ULEB128

    /// Read a ULEB128-encoded value
    public func readUleb128() throws -> UInt32 {
        let (value, bytesRead) = try Uleb128.decode(data, offset: offset)
        offset += bytesRead
        return value
    }

    // MARK: - Bytes and Strings

    /// Read fixed-length bytes (without length prefix)
    public func readFixedBytes(_ length: Int) throws -> [UInt8] {
        try checkRemaining(length)
        let result = Array(data[offset..<(offset + length)])
        offset += length
        return result
    }

    /// Read bytes with ULEB128 length prefix
    public func readBytes() throws -> [UInt8] {
        let length = Int(try readUleb128())
        try checkSequenceLength(length)
        return try readFixedBytes(length)
    }

    /// Read a UTF-8 string with ULEB128 length prefix
    public func readString() throws -> String {
        let bytes = try readBytes()
        guard let str = String(bytes: bytes, encoding: .utf8) else {
            throw BcsError.invalidUtf8()
        }
        return str
    }

    // MARK: - Composite Types

    /// Read an optional value
    public func readOption<T>(_ deserializer: (BcsDeserializer) throws -> T) throws -> T? {
        let tag = try readU8()
        switch tag {
        case 0: return nil
        case 1: return try deserializer(self)
        default: throw BcsError.invalidOption(tag)
        }
    }

    /// Read a vector with element deserializer
    public func readVector<T>(_ deserializer: (BcsDeserializer) throws -> T) throws -> [T] {
        let length = Int(try readUleb128())
        try checkSequenceLength(length)

        var result: [T] = []
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(try deserializer(self))
        }
        return result
    }

    /// Read a map with key/value deserializers
    public func readMap<K: Comparable, V>(
        keyDeserializer: (BcsDeserializer) throws -> K,
        valueDeserializer: (BcsDeserializer) throws -> V
    ) throws -> [K: V] {
        let length = Int(try readUleb128())
        try checkSequenceLength(length)

        var result: [K: V] = [:]
        result.reserveCapacity(length)
        var prevKeyBytes: [UInt8]?

        for _ in 0..<length {
            // Remember position before reading key
            let keyStart = offset

            let key = try keyDeserializer(self)

            // Get key bytes for ordering check
            let keyBytes = Array(data[keyStart..<offset])

            // Check ordering
            if let prev = prevKeyBytes {
                if keyBytes <= prev {
                    if keyBytes == prev {
                        throw BcsError.duplicateMapKey()
                    }
                    throw BcsError.nonCanonicalMap()
                }
            }
            prevKeyBytes = keyBytes

            let value = try valueDeserializer(self)
            result[key] = value
        }

        return result
    }

    /// Read an enum variant index
    public func readVariantIndex() throws -> UInt32 {
        try readUleb128()
    }

    // MARK: - Container Depth

    /// Enter a struct/enum container (for depth tracking)
    @discardableResult
    public func enterContainer() throws -> BcsDeserializer {
        depth += 1
        if depth > BcsConstants.maxContainerDepth {
            throw BcsError.exceededContainerDepth(depth)
        }
        return self
    }

    /// Leave a struct/enum container
    @discardableResult
    public func leaveContainer() -> BcsDeserializer {
        depth -= 1
        return self
    }

    // MARK: - State

    /// Check that all input has been consumed
    public func checkEnd() throws {
        if offset < data.count {
            throw BcsError.remainingInput(data.count - offset)
        }
    }

    /// Get the current offset
    public var currentOffset: Int {
        offset
    }

    /// Get the remaining bytes count
    public var remaining: Int {
        data.count - offset
    }

    /// Check if there's more data to read
    public var hasRemaining: Bool {
        offset < data.count
    }

    // MARK: - Private

    private func checkRemaining(_ needed: Int) throws {
        if offset + needed > data.count {
            throw BcsError.unexpectedEof()
        }
    }

    private func checkSequenceLength(_ length: Int) throws {
        if length > BcsConstants.maxSequenceLength {
            throw BcsError.exceededMaxLength(length)
        }
    }
}

// MARK: - Array Comparison Extension

extension Array where Element == UInt8 {
    static func <= (lhs: [UInt8], rhs: [UInt8]) -> Bool {
        lhs.lexicographicallyPrecedes(rhs) || lhs == rhs
    }
}
