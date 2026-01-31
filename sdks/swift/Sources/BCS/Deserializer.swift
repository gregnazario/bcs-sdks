// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// BCS Deserializer - Manual deserialization API
public final class BcsDeserializer {
    @usableFromInline
    internal let data: [UInt8]
    @usableFromInline
    internal var offset: Int = 0
    @usableFromInline
    internal var depth: Int = 0

    /// Create a deserializer from a byte array
    @inlinable
    public init(_ data: [UInt8]) {
        self.data = data
    }

    /// Create a deserializer from Data
    @inlinable
    public init(_ data: Data) {
        self.data = Array(data)
    }

    // MARK: - Boolean

    /// Read a boolean value
    @inlinable
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
    @inlinable
    public func readU8() throws -> UInt8 {
        guard offset < data.count else {
            throw BcsError.unexpectedEof()
        }
        let value = data[offset]
        offset &+= 1
        return value
    }

    /// Read an unsigned 16-bit integer (little-endian)
    @inlinable
    public func readU16() throws -> UInt16 {
        guard offset &+ 2 <= data.count else {
            throw BcsError.unexpectedEof()
        }
        let value = UInt16(data[offset]) | (UInt16(data[offset &+ 1]) &<< 8)
        offset &+= 2
        return value
    }

    /// Read an unsigned 32-bit integer (little-endian)
    @inlinable
    public func readU32() throws -> UInt32 {
        guard offset &+ 4 <= data.count else {
            throw BcsError.unexpectedEof()
        }
        let value =
            UInt32(data[offset])
            | (UInt32(data[offset &+ 1]) &<< 8)
            | (UInt32(data[offset &+ 2]) &<< 16)
            | (UInt32(data[offset &+ 3]) &<< 24)
        offset &+= 4
        return value
    }

    /// Read an unsigned 64-bit integer (little-endian)
    @inlinable
    public func readU64() throws -> UInt64 {
        guard offset &+ 8 <= data.count else {
            throw BcsError.unexpectedEof()
        }
        let value =
            UInt64(data[offset])
            | (UInt64(data[offset &+ 1]) &<< 8)
            | (UInt64(data[offset &+ 2]) &<< 16)
            | (UInt64(data[offset &+ 3]) &<< 24)
            | (UInt64(data[offset &+ 4]) &<< 32)
            | (UInt64(data[offset &+ 5]) &<< 40)
            | (UInt64(data[offset &+ 6]) &<< 48)
            | (UInt64(data[offset &+ 7]) &<< 56)
        offset &+= 8
        return value
    }

    /// Read an unsigned 128-bit integer (little-endian byte array)
    @inlinable
    public func readU128() throws -> [UInt8] {
        try readFixedBytes(16)
    }

    /// Read an unsigned 256-bit integer (little-endian byte array)
    @inlinable
    public func readU256() throws -> [UInt8] {
        try readFixedBytes(32)
    }

    // MARK: - Signed Integers

    /// Read a signed 8-bit integer
    @inlinable
    public func readI8() throws -> Int8 {
        Int8(bitPattern: try readU8())
    }

    /// Read a signed 16-bit integer (little-endian)
    @inlinable
    public func readI16() throws -> Int16 {
        Int16(bitPattern: try readU16())
    }

    /// Read a signed 32-bit integer (little-endian)
    @inlinable
    public func readI32() throws -> Int32 {
        Int32(bitPattern: try readU32())
    }

    /// Read a signed 64-bit integer (little-endian)
    @inlinable
    public func readI64() throws -> Int64 {
        Int64(bitPattern: try readU64())
    }

    /// Read a signed 128-bit integer (little-endian byte array)
    @inlinable
    public func readI128() throws -> [UInt8] {
        try readU128()
    }

    /// Read a signed 256-bit integer (little-endian byte array)
    @inlinable
    public func readI256() throws -> [UInt8] {
        try readU256()
    }

    // MARK: - ULEB128

    /// Read a ULEB128-encoded value
    @inlinable
    public func readUleb128() throws -> UInt32 {
        guard offset < data.count else {
            throw BcsError.unexpectedEof()
        }

        // Fast path for single-byte values (0-127)
        let first = data[offset]
        if first < 0x80 {
            offset &+= 1
            return UInt32(first)
        }

        // Multi-byte path
        var value: UInt32 = UInt32(first & 0x7F)
        var shift: UInt32 = 7
        offset &+= 1

        for i in 1..<5 {
            guard offset < data.count else {
                throw BcsError.unexpectedEof()
            }

            let byte = data[offset]
            offset &+= 1
            let digit = byte & 0x7F

            value |= UInt32(digit) &<< shift

            // Check if this is the last byte (high bit not set)
            if (byte & 0x80) == 0 {
                // Check for non-canonical encoding (trailing zeros)
                if digit == 0 {
                    throw BcsError.nonCanonicalUleb128()
                }

                // Check for overflow on final byte
                if i == 4 && digit > 0x0F {
                    throw BcsError.uleb128Overflow()
                }

                return value
            }

            shift &+= 7
        }

        // If we've read 5 bytes and still have continuation bit, overflow
        throw BcsError.uleb128Overflow()
    }

    // MARK: - Bytes and Strings

    /// Read fixed-length bytes (without length prefix)
    @inlinable
    public func readFixedBytes(_ length: Int) throws -> [UInt8] {
        guard offset &+ length <= data.count else {
            throw BcsError.unexpectedEof()
        }
        let result = Array(data[offset..<(offset &+ length)])
        offset &+= length
        return result
    }

    /// Read bytes with ULEB128 length prefix
    @inlinable
    public func readBytes() throws -> [UInt8] {
        let length = try uleb128ToInt(try readUleb128())
        try checkSequenceLength(length)
        return try readFixedBytes(length)
    }

    /// Read a UTF-8 string with ULEB128 length prefix
    @inlinable
    public func readString() throws -> String {
        let length = try uleb128ToInt(try readUleb128())
        try checkSequenceLength(length)
        guard offset &+ length <= data.count else {
            throw BcsError.unexpectedEof()
        }
        // Create string directly from slice to avoid intermediate array allocation
        let endOffset = offset &+ length
        let str = data[offset..<endOffset].withUnsafeBufferPointer { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
        // Validate UTF-8 by checking if round-trip produces same length
        if str.utf8.count != length {
            throw BcsError.invalidUtf8()
        }
        offset = endOffset
        return str
    }

    // MARK: - Composite Types

    /// Read an optional value
    @inlinable
    public func readOption<T>(_ deserializer: (BcsDeserializer) throws -> T) throws -> T? {
        let tag = try readU8()
        switch tag {
        case 0: return nil
        case 1: return try deserializer(self)
        default: throw BcsError.invalidOption(tag)
        }
    }

    /// Read a vector with element deserializer
    @inlinable
    public func readVector<T>(_ deserializer: (BcsDeserializer) throws -> T) throws -> [T] {
        let length = try uleb128ToInt(try readUleb128())
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
        let length = try uleb128ToInt(try readUleb128())
        try checkSequenceLength(length)

        var result: [K: V] = [:]
        result.reserveCapacity(length)
        var prevKeyBytes: ArraySlice<UInt8>?

        for _ in 0..<length {
            // Remember position before reading key
            let keyStart = offset

            let key = try keyDeserializer(self)

            // Get key bytes for ordering check (use slice to avoid allocation)
            let keyBytes = data[keyStart..<offset]

            // Check ordering
            if let prev = prevKeyBytes {
                if keyBytes.lexicographicallyPrecedes(prev) || keyBytes.elementsEqual(prev) {
                    if keyBytes.elementsEqual(prev) {
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
    @inlinable
    public func readVariantIndex() throws -> UInt32 {
        try readUleb128()
    }

    // MARK: - Container Depth

    /// Enter a struct/enum container (for depth tracking)
    @inlinable
    @discardableResult
    public func enterContainer() throws -> BcsDeserializer {
        if depth >= BcsConstants.maxContainerDepth {
            throw BcsError.exceededContainerDepth(depth + 1)
        }
        depth &+= 1
        return self
    }

    /// Leave a struct/enum container
    @inlinable
    @discardableResult
    public func leaveContainer() -> BcsDeserializer {
        if depth > 0 {
            depth -= 1
        }
        return self
    }

    // MARK: - State

    /// Check that all input has been consumed
    @inlinable
    public func checkEnd() throws {
        if offset < data.count {
            throw BcsError.remainingInput(data.count - offset)
        }
    }

    /// Get the current offset
    @inlinable
    public var currentOffset: Int {
        offset
    }

    /// Get the remaining bytes count
    @inlinable
    public var remaining: Int {
        data.count - offset
    }

    /// Check if there's more data to read
    @inlinable
    public var hasRemaining: Bool {
        offset < data.count
    }

    /// Peek at the next byte without consuming it
    @inlinable
    public func peek() throws -> UInt8 {
        guard offset < data.count else {
            throw BcsError.unexpectedEof()
        }
        return data[offset]
    }

    /// Skip n bytes
    @inlinable
    @discardableResult
    public func skip(_ n: Int) throws -> BcsDeserializer {
        guard offset &+ n <= data.count else {
            throw BcsError.unexpectedEof()
        }
        offset &+= n
        return self
    }

    /// Read fixed-length bytes as a slice (zero-copy view)
    @inlinable
    public func readFixedBytesSlice(_ length: Int) throws -> ArraySlice<UInt8> {
        guard offset &+ length <= data.count else {
            throw BcsError.unexpectedEof()
        }
        let result = data[offset..<(offset &+ length)]
        offset &+= length
        return result
    }

    // MARK: - Batch Read Operations

    /// Read a vector of U8 values efficiently
    @inlinable
    public func readU8Vector() throws -> [UInt8] {
        let length = try uleb128ToInt(try readUleb128())
        try checkSequenceLength(length)
        return try readFixedBytes(length)
    }

    /// Read a vector of U16 values efficiently
    @inlinable
    public func readU16Vector() throws -> [UInt16] {
        let uleb = try readUleb128()
        // Check for overflow: length * 2 must fit in Int
        guard uleb <= UInt32(Int.max / 2) else {
            throw BcsError.exceededMaxLength(Int(truncatingIfNeeded: uleb))
        }
        let length = Int(uleb)
        try checkSequenceLength(length)
        let byteCount = length * 2
        // Check bounds without overflow: ensure remaining bytes >= byteCount
        guard data.count - offset >= byteCount else {
            throw BcsError.unexpectedEof()
        }
        var result = [UInt16]()
        result.reserveCapacity(length)
        for _ in 0..<length {
            let value = UInt16(data[offset]) | (UInt16(data[offset &+ 1]) &<< 8)
            offset &+= 2
            result.append(value)
        }
        return result
    }

    /// Read a vector of U32 values efficiently
    @inlinable
    public func readU32Vector() throws -> [UInt32] {
        let uleb = try readUleb128()
        // Check for overflow: length * 4 must fit in Int
        guard uleb <= UInt32(Int.max / 4) else {
            throw BcsError.exceededMaxLength(Int(truncatingIfNeeded: uleb))
        }
        let length = Int(uleb)
        try checkSequenceLength(length)
        let byteCount = length * 4
        // Check bounds without overflow: ensure remaining bytes >= byteCount
        guard data.count - offset >= byteCount else {
            throw BcsError.unexpectedEof()
        }
        var result = [UInt32]()
        result.reserveCapacity(length)
        for _ in 0..<length {
            let value =
                UInt32(data[offset])
                | (UInt32(data[offset &+ 1]) &<< 8)
                | (UInt32(data[offset &+ 2]) &<< 16)
                | (UInt32(data[offset &+ 3]) &<< 24)
            offset &+= 4
            result.append(value)
        }
        return result
    }

    /// Read a vector of U64 values efficiently
    @inlinable
    public func readU64Vector() throws -> [UInt64] {
        let uleb = try readUleb128()
        // Check for overflow: length * 8 must fit in Int
        guard uleb <= UInt32(Int.max / 8) else {
            throw BcsError.exceededMaxLength(Int(truncatingIfNeeded: uleb))
        }
        let length = Int(uleb)
        try checkSequenceLength(length)
        let byteCount = length * 8
        // Check bounds without overflow: ensure remaining bytes >= byteCount
        guard data.count - offset >= byteCount else {
            throw BcsError.unexpectedEof()
        }
        var result = [UInt64]()
        result.reserveCapacity(length)
        for _ in 0..<length {
            let value =
                UInt64(data[offset])
                | (UInt64(data[offset &+ 1]) &<< 8)
                | (UInt64(data[offset &+ 2]) &<< 16)
                | (UInt64(data[offset &+ 3]) &<< 24)
                | (UInt64(data[offset &+ 4]) &<< 32)
                | (UInt64(data[offset &+ 5]) &<< 40)
                | (UInt64(data[offset &+ 6]) &<< 48)
                | (UInt64(data[offset &+ 7]) &<< 56)
            offset &+= 8
            result.append(value)
        }
        return result
    }

    // MARK: - Private

    /// Safely convert ULEB128 value to Int, handling 32-bit platform overflow
    @usableFromInline
    internal func uleb128ToInt(_ value: UInt32) throws -> Int {
        // On 32-bit platforms, Int.max is 2^31-1, so UInt32 values > Int.max would overflow
        guard value <= UInt32(Int.max) else {
            throw BcsError.exceededMaxLength(Int(truncatingIfNeeded: value))
        }
        return Int(value)
    }

    @usableFromInline
    internal func checkSequenceLength(_ length: Int) throws {
        if length > BcsConstants.maxSequenceLength {
            throw BcsError.exceededMaxLength(length)
        }
    }
}
