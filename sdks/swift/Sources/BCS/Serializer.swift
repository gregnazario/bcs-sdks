// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// BCS Serializer — manual serialization API.
///
/// Provides explicit methods for serializing each BCS type with method chaining.
///
/// ```swift
/// let ser = BcsSerializer()
/// ser.writeU64(12345)
/// try ser.writeString("hello")
/// ser.writeBool(true)
/// let bytes = ser.toBytes()
/// ```
public final class BcsSerializer {
    @usableFromInline
    internal var buffer: ContiguousArray<UInt8> = []
    @usableFromInline
    internal var depth: Int = 0

    @inlinable
    public init() {
        buffer.reserveCapacity(256)
    }

    // MARK: - Boolean

    /// Serialize a boolean value (`0x00` = false, `0x01` = true).
    ///
    /// - Parameter value: The boolean to serialize.
    /// - Returns: `self` for method chaining.
    @inlinable
    @discardableResult
    public func writeBool(_ value: Bool) -> BcsSerializer {
        buffer.append(value ? 1 : 0)
        return self
    }

    // MARK: - Unsigned Integers

    /// Serialize an unsigned 8-bit integer.
    ///
    /// - Parameter value: Value to serialize (0–255).
    /// - Returns: `self` for method chaining.
    @inlinable
    @discardableResult
    public func writeU8(_ value: UInt8) -> BcsSerializer {
        buffer.append(value)
        return self
    }

    /// Write an unsigned 16-bit integer (little-endian)
    @inlinable
    @discardableResult
    public func writeU16(_ value: UInt16) -> BcsSerializer {
        buffer.append(UInt8(truncatingIfNeeded: value))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 8))
        return self
    }

    /// Write an unsigned 32-bit integer (little-endian)
    @inlinable
    @discardableResult
    public func writeU32(_ value: UInt32) -> BcsSerializer {
        buffer.append(UInt8(truncatingIfNeeded: value))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 8))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 16))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 24))
        return self
    }

    /// Write an unsigned 64-bit integer (little-endian)
    @inlinable
    @discardableResult
    public func writeU64(_ value: UInt64) -> BcsSerializer {
        buffer.append(UInt8(truncatingIfNeeded: value))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 8))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 16))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 24))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 32))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 40))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 48))
        buffer.append(UInt8(truncatingIfNeeded: value &>> 56))
        return self
    }

    /// Serialize an unsigned 128-bit integer as a 16-byte little-endian array.
    ///
    /// - Parameter value: Exactly 16 bytes in little-endian order.
    /// - Returns: `self` for method chaining.
    /// - Throws: `BcsError.integerOutOfRange` if `value` is not 16 bytes.
    @inlinable
    @discardableResult
    public func writeU128(_ value: [UInt8]) throws -> BcsSerializer {
        guard value.count == 16 else {
            throw BcsError.integerOutOfRange("u128 must be 16 bytes")
        }
        buffer.append(contentsOf: value)
        return self
    }

    /// Serialize an unsigned 256-bit integer as a 32-byte little-endian array.
    ///
    /// - Parameter value: Exactly 32 bytes in little-endian order.
    /// - Returns: `self` for method chaining.
    /// - Throws: `BcsError.integerOutOfRange` if `value` is not 32 bytes.
    @inlinable
    @discardableResult
    public func writeU256(_ value: [UInt8]) throws -> BcsSerializer {
        guard value.count == 32 else {
            throw BcsError.integerOutOfRange("u256 must be 32 bytes")
        }
        buffer.append(contentsOf: value)
        return self
    }

    // MARK: - Signed Integers

    /// Write a signed 8-bit integer
    @inlinable
    @discardableResult
    public func writeI8(_ value: Int8) -> BcsSerializer {
        buffer.append(UInt8(bitPattern: value))
        return self
    }

    /// Write a signed 16-bit integer (little-endian)
    @inlinable
    @discardableResult
    public func writeI16(_ value: Int16) -> BcsSerializer {
        writeU16(UInt16(bitPattern: value))
    }

    /// Write a signed 32-bit integer (little-endian)
    @inlinable
    @discardableResult
    public func writeI32(_ value: Int32) -> BcsSerializer {
        writeU32(UInt32(bitPattern: value))
    }

    /// Write a signed 64-bit integer (little-endian)
    @inlinable
    @discardableResult
    public func writeI64(_ value: Int64) -> BcsSerializer {
        writeU64(UInt64(bitPattern: value))
    }

    /// Write a signed 128-bit integer (little-endian byte array)
    @inlinable
    @discardableResult
    public func writeI128(_ value: [UInt8]) throws -> BcsSerializer {
        try writeU128(value)
    }

    /// Write a signed 256-bit integer (little-endian byte array)
    @inlinable
    @discardableResult
    public func writeI256(_ value: [UInt8]) throws -> BcsSerializer {
        try writeU256(value)
    }

    // MARK: - ULEB128

    /// Write a ULEB128-encoded length
    @inlinable
    @discardableResult
    public func writeUleb128(_ value: UInt32) -> BcsSerializer {
        // Fast path for single-byte values (0-127)
        if value < 0x80 {
            buffer.append(UInt8(value))
            return self
        }
        // Multi-byte path
        var remaining = value
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining &>>= 7
            if remaining != 0 {
                byte |= 0x80  // Set continuation bit
            }
            buffer.append(byte)
        } while remaining != 0
        return self
    }

    // MARK: - Bytes and Strings

    /// Write raw bytes (without length prefix)
    @inlinable
    @discardableResult
    public func writeFixedBytes(_ data: [UInt8]) -> BcsSerializer {
        buffer.append(contentsOf: data)
        return self
    }

    /// Serialize a byte array with ULEB128 length prefix.
    ///
    /// - Parameter data: Bytes to serialize.
    /// - Returns: `self` for method chaining.
    /// - Throws: `BcsError.exceededMaxLength` if length exceeds the maximum.
    @inlinable
    @discardableResult
    public func writeBytes(_ data: [UInt8]) throws -> BcsSerializer {
        try checkSequenceLength(data.count)
        writeUleb128(UInt32(data.count))
        buffer.append(contentsOf: data)
        return self
    }

    /// Serialize a UTF-8 string with ULEB128 length prefix.
    ///
    /// - Parameter value: String to serialize.
    /// - Returns: `self` for method chaining.
    /// - Throws: `BcsError.exceededMaxLength` if byte length exceeds the maximum.
    @inlinable
    @discardableResult
    public func writeString(_ value: String) throws -> BcsSerializer {
        // Use contiguousUTF8 for optimal performance when available
        var str = value
        return try str.withUTF8 { utf8Buffer in
            try self.checkSequenceLength(utf8Buffer.count)
            self.writeUleb128(UInt32(utf8Buffer.count))
            self.buffer.append(contentsOf: utf8Buffer)
            return self
        }
    }

    // MARK: - Composite Types

    /// Serialize an optional value (`None` = `0x00`, `Some` = `0x01` + value).
    ///
    /// - Parameters:
    ///   - opt: The optional value, or `nil`.
    ///   - serializer: Closure to serialize the inner value if present.
    /// - Returns: `self` for method chaining.
    /// - Throws: Rethrows any error from `serializer`.
    @inlinable
    @discardableResult
    public func writeOption<T>(_ opt: T?, serializer: (BcsSerializer, T) throws -> Void) throws -> BcsSerializer {
        if let value = opt {
            buffer.append(1)
            try serializer(self, value)
        } else {
            buffer.append(0)
        }
        return self
    }

    /// Serialize a vector with ULEB128 length prefix and per-element serializer.
    ///
    /// - Parameters:
    ///   - values: Array of elements to serialize.
    ///   - serializer: Closure to serialize each element.
    /// - Returns: `self` for method chaining.
    /// - Throws: `BcsError.exceededMaxLength` or any error from `serializer`.
    @inlinable
    @discardableResult
    public func writeVector<T>(_ values: [T], serializer: (BcsSerializer, T) throws -> Void) throws -> BcsSerializer {
        try checkSequenceLength(values.count)
        writeUleb128(UInt32(values.count))
        for value in values {
            try serializer(self, value)
        }
        return self
    }

    /// Serialize a map sorted by serialized key bytes.
    ///
    /// Keys are serialized, sorted lexicographically by their byte representation,
    /// then the sorted entries are written with ULEB128 length prefix.
    ///
    /// - Parameters:
    ///   - map: Dictionary to serialize.
    ///   - keySerializer: Closure to serialize each key.
    ///   - valueSerializer: Closure to serialize each value.
    /// - Returns: `self` for method chaining.
    /// - Throws: `BcsError.exceededMaxLength` or any error from the serializer closures.
    @discardableResult
    public func writeMap<K, V>(
        _ map: [K: V],
        keySerializer: (BcsSerializer, K) throws -> Void,
        valueSerializer: (BcsSerializer, V) throws -> Void
    ) throws -> BcsSerializer {
        try checkSequenceLength(map.count)

        // Serialize all entries and sort by key bytes
        var entries: [(key: [UInt8], value: [UInt8])] = []
        entries.reserveCapacity(map.count)

        // Reuse single serializer to reduce allocations
        let tempSer = BcsSerializer()
        for (key, value) in map {
            tempSer.clear()
            try keySerializer(tempSer, key)
            let keyBytes = tempSer.toBytes()

            tempSer.clear()
            try valueSerializer(tempSer, value)

            entries.append((key: keyBytes, value: tempSer.toBytes()))
        }

        // Sort by key bytes (lexicographic)
        entries.sort { $0.key.lexicographicallyPrecedes($1.key) }

        // Write length and entries
        writeUleb128(UInt32(entries.count))
        for entry in entries {
            buffer.append(contentsOf: entry.key)
            buffer.append(contentsOf: entry.value)
        }

        return self
    }

    /// Write an enum variant index
    @inlinable
    @discardableResult
    public func writeVariantIndex(_ index: UInt32) -> BcsSerializer {
        writeUleb128(index)
    }

    // MARK: - Batch Write Operations

    /// Write a vector of U8 values efficiently
    @inlinable
    @discardableResult
    public func writeU8Vector(_ values: [UInt8]) throws -> BcsSerializer {
        try checkSequenceLength(values.count)
        writeUleb128(UInt32(values.count))
        buffer.append(contentsOf: values)
        return self
    }

    /// Write a vector of U16 values efficiently
    @inlinable
    @discardableResult
    public func writeU16Vector(_ values: [UInt16]) throws -> BcsSerializer {
        try checkSequenceLength(values.count)
        writeUleb128(UInt32(values.count))
        buffer.reserveCapacity(buffer.count + values.count * 2)
        for value in values {
            buffer.append(UInt8(truncatingIfNeeded: value))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 8))
        }
        return self
    }

    /// Write a vector of U32 values efficiently
    @inlinable
    @discardableResult
    public func writeU32Vector(_ values: [UInt32]) throws -> BcsSerializer {
        try checkSequenceLength(values.count)
        writeUleb128(UInt32(values.count))
        buffer.reserveCapacity(buffer.count + values.count * 4)
        for value in values {
            buffer.append(UInt8(truncatingIfNeeded: value))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 8))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 16))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 24))
        }
        return self
    }

    /// Write a vector of U64 values efficiently
    @inlinable
    @discardableResult
    public func writeU64Vector(_ values: [UInt64]) throws -> BcsSerializer {
        try checkSequenceLength(values.count)
        writeUleb128(UInt32(values.count))
        buffer.reserveCapacity(buffer.count + values.count * 8)
        for value in values {
            buffer.append(UInt8(truncatingIfNeeded: value))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 8))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 16))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 24))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 32))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 40))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 48))
            buffer.append(UInt8(truncatingIfNeeded: value &>> 56))
        }
        return self
    }

    // MARK: - Container Depth

    /// Enter a struct/enum container for depth tracking.
    ///
    /// - Returns: `self` for method chaining.
    /// - Throws: `BcsError.exceededContainerDepth` if depth exceeds the maximum.
    @inlinable
    @discardableResult
    public func enterContainer() throws -> BcsSerializer {
        if depth >= BcsConstants.maxContainerDepth {
            throw BcsError.exceededContainerDepth(depth + 1)
        }
        depth += 1
        return self
    }

    /// Leave a struct/enum container
    @inlinable
    @discardableResult
    public func leaveContainer() -> BcsSerializer {
        if depth > 0 {
            depth -= 1
        }
        return self
    }

    // MARK: - Output

    /// Get a copy of the serialized bytes.
    ///
    /// - Returns: New array containing the serialized data.
    @inlinable
    public func toBytes() -> [UInt8] {
        Array(buffer)
    }

    /// Get direct access to the internal buffer (zero-copy)
    @inlinable
    public var bytes: ContiguousArray<UInt8> {
        buffer
    }

    /// Get the current size of the buffer
    @inlinable
    public var size: Int {
        buffer.count
    }

    /// Clear the buffer
    @inlinable
    public func clear() {
        buffer.removeAll(keepingCapacity: true)
        depth = 0
    }

    // MARK: - Private

    @usableFromInline
    internal func checkSequenceLength(_ length: Int) throws {
        if length > BcsConstants.maxSequenceLength {
            throw BcsError.exceededMaxLength(length)
        }
    }
}
