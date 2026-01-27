// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// BCS Serializer - Manual serialization API
public final class BcsSerializer {
    private var buffer: [UInt8] = []
    private var depth: Int = 0

    public init() {
        buffer.reserveCapacity(256)
    }

    // MARK: - Boolean

    /// Write a boolean value
    @discardableResult
    public func writeBool(_ value: Bool) -> BcsSerializer {
        buffer.append(value ? 1 : 0)
        return self
    }

    // MARK: - Unsigned Integers

    /// Write an unsigned 8-bit integer
    @discardableResult
    public func writeU8(_ value: UInt8) -> BcsSerializer {
        buffer.append(value)
        return self
    }

    /// Write an unsigned 16-bit integer (little-endian)
    @discardableResult
    public func writeU16(_ value: UInt16) -> BcsSerializer {
        buffer.append(UInt8(value & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        return self
    }

    /// Write an unsigned 32-bit integer (little-endian)
    @discardableResult
    public func writeU32(_ value: UInt32) -> BcsSerializer {
        buffer.append(UInt8(value & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 24) & 0xFF))
        return self
    }

    /// Write an unsigned 64-bit integer (little-endian)
    @discardableResult
    public func writeU64(_ value: UInt64) -> BcsSerializer {
        for i in 0..<8 {
            buffer.append(UInt8((value >> (i * 8)) & 0xFF))
        }
        return self
    }

    /// Write an unsigned 128-bit integer (little-endian byte array)
    @discardableResult
    public func writeU128(_ value: [UInt8]) throws -> BcsSerializer {
        guard value.count == 16 else {
            throw BcsError.integerOutOfRange("u128 must be 16 bytes")
        }
        buffer.append(contentsOf: value)
        return self
    }

    /// Write an unsigned 256-bit integer (little-endian byte array)
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
    @discardableResult
    public func writeI8(_ value: Int8) -> BcsSerializer {
        buffer.append(UInt8(bitPattern: value))
        return self
    }

    /// Write a signed 16-bit integer (little-endian)
    @discardableResult
    public func writeI16(_ value: Int16) -> BcsSerializer {
        writeU16(UInt16(bitPattern: value))
    }

    /// Write a signed 32-bit integer (little-endian)
    @discardableResult
    public func writeI32(_ value: Int32) -> BcsSerializer {
        writeU32(UInt32(bitPattern: value))
    }

    /// Write a signed 64-bit integer (little-endian)
    @discardableResult
    public func writeI64(_ value: Int64) -> BcsSerializer {
        writeU64(UInt64(bitPattern: value))
    }

    /// Write a signed 128-bit integer (little-endian byte array)
    @discardableResult
    public func writeI128(_ value: [UInt8]) throws -> BcsSerializer {
        try writeU128(value)
    }

    /// Write a signed 256-bit integer (little-endian byte array)
    @discardableResult
    public func writeI256(_ value: [UInt8]) throws -> BcsSerializer {
        try writeU256(value)
    }

    // MARK: - ULEB128

    /// Write a ULEB128-encoded length
    @discardableResult
    public func writeUleb128(_ value: UInt32) -> BcsSerializer {
        let encoded = Uleb128.encode(value)
        buffer.append(contentsOf: encoded)
        return self
    }

    // MARK: - Bytes and Strings

    /// Write raw bytes (without length prefix)
    @discardableResult
    public func writeFixedBytes(_ data: [UInt8]) -> BcsSerializer {
        buffer.append(contentsOf: data)
        return self
    }

    /// Write bytes with ULEB128 length prefix
    @discardableResult
    public func writeBytes(_ data: [UInt8]) throws -> BcsSerializer {
        try checkSequenceLength(data.count)
        writeUleb128(UInt32(data.count))
        buffer.append(contentsOf: data)
        return self
    }

    /// Write a UTF-8 string with ULEB128 length prefix
    @discardableResult
    public func writeString(_ value: String) throws -> BcsSerializer {
        let bytes = Array(value.utf8)
        return try writeBytes(bytes)
    }

    // MARK: - Composite Types

    /// Write an optional value
    @discardableResult
    public func writeOption<T>(_ opt: T?, serializer: (BcsSerializer, T) throws -> Void) throws -> BcsSerializer {
        if let value = opt {
            writeU8(1)
            try serializer(self, value)
        } else {
            writeU8(0)
        }
        return self
    }

    /// Write a vector with element serializer
    @discardableResult
    public func writeVector<T>(_ values: [T], serializer: (BcsSerializer, T) throws -> Void) throws -> BcsSerializer {
        try checkSequenceLength(values.count)
        writeUleb128(UInt32(values.count))
        for value in values {
            try serializer(self, value)
        }
        return self
    }

    /// Write a map with key/value serializers (sorted by serialized key bytes)
    @discardableResult
    public func writeMap<K, V>(
        _ map: [K: V],
        keySerializer: (BcsSerializer, K) throws -> Void,
        valueSerializer: (BcsSerializer, V) throws -> Void
    ) throws -> BcsSerializer {
        try checkSequenceLength(map.count)

        // Serialize all entries and sort by key bytes
        var entries: [([UInt8], [UInt8])] = []
        entries.reserveCapacity(map.count)

        for (key, value) in map {
            let keySer = BcsSerializer()
            try keySerializer(keySer, key)

            let valueSer = BcsSerializer()
            try valueSerializer(valueSer, value)

            entries.append((keySer.toBytes(), valueSer.toBytes()))
        }

        // Sort by key bytes (lexicographic)
        entries.sort { $0.0.lexicographicallyPrecedes($1.0) }

        // Write length and entries
        writeUleb128(UInt32(entries.count))
        for (keyBytes, valueBytes) in entries {
            buffer.append(contentsOf: keyBytes)
            buffer.append(contentsOf: valueBytes)
        }

        return self
    }

    /// Write an enum variant index
    @discardableResult
    public func writeVariantIndex(_ index: UInt32) -> BcsSerializer {
        writeUleb128(index)
    }

    // MARK: - Container Depth

    /// Enter a struct/enum container (for depth tracking)
    @discardableResult
    public func enterContainer() throws -> BcsSerializer {
        depth += 1
        if depth > BcsConstants.maxContainerDepth {
            throw BcsError.exceededContainerDepth(depth)
        }
        return self
    }

    /// Leave a struct/enum container
    @discardableResult
    public func leaveContainer() -> BcsSerializer {
        depth -= 1
        return self
    }

    // MARK: - Output

    /// Get the serialized bytes
    public func toBytes() -> [UInt8] {
        buffer
    }

    /// Get the current size of the buffer
    public var size: Int {
        buffer.count
    }

    /// Clear the buffer
    public func clear() {
        buffer.removeAll(keepingCapacity: true)
        depth = 0
    }

    // MARK: - Private

    private func checkSequenceLength(_ length: Int) throws {
        if length > BcsConstants.maxSequenceLength {
            throw BcsError.exceededMaxLength(length)
        }
    }
}
