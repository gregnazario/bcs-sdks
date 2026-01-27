// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@testable import BCS

// MARK: - ULEB128 Tests

final class Uleb128Tests: XCTestCase {

    func testUleb128Encode() {
        XCTAssertEqual(Uleb128.encode(0), [0x00])
        XCTAssertEqual(Uleb128.encode(1), [0x01])
        XCTAssertEqual(Uleb128.encode(127), [0x7f])
        XCTAssertEqual(Uleb128.encode(128), [0x80, 0x01])
        XCTAssertEqual(Uleb128.encode(255), [0xff, 0x01])
        XCTAssertEqual(Uleb128.encode(300), [0xac, 0x02])
        XCTAssertEqual(Uleb128.encode(16384), [0x80, 0x80, 0x01])
        XCTAssertEqual(Uleb128.encode(UInt32.max), [0xff, 0xff, 0xff, 0xff, 0x0f])
    }

    func testUleb128Decode() throws {
        XCTAssertEqual(try Uleb128.decode([0x00]).value, 0)
        XCTAssertEqual(try Uleb128.decode([0x7f]).value, 127)
        XCTAssertEqual(try Uleb128.decode([0x80, 0x01]).value, 128)
        XCTAssertEqual(try Uleb128.decode([0xff, 0xff, 0xff, 0xff, 0x0f]).value, UInt32.max)
    }

    func testUleb128RejectNonCanonical() {
        // 0 with trailing zero
        XCTAssertThrowsError(try Uleb128.decode([0x80, 0x00])) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .nonCanonicalUleb128)
        }
    }

    func testUleb128RejectOverflow() {
        // Value > UInt32.max
        XCTAssertThrowsError(try Uleb128.decode([0xff, 0xff, 0xff, 0xff, 0x1f])) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .uleb128Overflow)
        }
    }
}

// MARK: - Primitive Type Tests

final class PrimitiveTypeTests: XCTestCase {

    func testBoolSerialization() {
        XCTAssertEqual(BCS.serializeBool(true), [0x01])
        XCTAssertEqual(BCS.serializeBool(false), [0x00])
    }

    func testBoolDeserialization() throws {
        XCTAssertEqual(try BCS.deserializeBool([0x01]), true)
        XCTAssertEqual(try BCS.deserializeBool([0x00]), false)
    }

    func testBoolInvalidValue() {
        XCTAssertThrowsError(try BCS.deserializeBool([0x02])) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .invalidBoolean(0x02))
        }
    }

    func testU8Serialization() {
        XCTAssertEqual(BCS.serializeU8(0), [0x00])
        XCTAssertEqual(BCS.serializeU8(255), [0xff])
        XCTAssertEqual(BCS.serializeU8(42), [0x2a])
    }

    func testU16Serialization() {
        XCTAssertEqual(BCS.serializeU16(0), [0x00, 0x00])
        XCTAssertEqual(BCS.serializeU16(0x1234), [0x34, 0x12])
        XCTAssertEqual(BCS.serializeU16(0xFFFF), [0xff, 0xff])
    }

    func testU32Serialization() {
        XCTAssertEqual(BCS.serializeU32(0), [0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(BCS.serializeU32(0x1234_5678), [0x78, 0x56, 0x34, 0x12])
    }

    func testU64Serialization() {
        XCTAssertEqual(BCS.serializeU64(0), [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(BCS.serializeU64(0x1234_5678_9ABC_DEF0), [0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12])
    }

    func testI8Serialization() {
        let ser = BcsSerializer()
        ser.writeI8(-1)
        XCTAssertEqual(ser.toBytes(), [0xff])

        ser.clear()
        ser.writeI8(-128)
        XCTAssertEqual(ser.toBytes(), [0x80])

        ser.clear()
        ser.writeI8(127)
        XCTAssertEqual(ser.toBytes(), [0x7f])
    }

    func testI16Serialization() {
        let ser = BcsSerializer()
        ser.writeI16(-1)
        XCTAssertEqual(ser.toBytes(), [0xff, 0xff])

        ser.clear()
        ser.writeI16(-32768)
        XCTAssertEqual(ser.toBytes(), [0x00, 0x80])
    }

    func testI32Serialization() {
        let ser = BcsSerializer()
        ser.writeI32(-1)
        XCTAssertEqual(ser.toBytes(), [0xff, 0xff, 0xff, 0xff])

        ser.clear()
        ser.writeI32(2147483647)  // max
        XCTAssertEqual(ser.toBytes(), [0xff, 0xff, 0xff, 0x7f])

        ser.clear()
        ser.writeI32(-2147483648)  // min
        XCTAssertEqual(ser.toBytes(), [0x00, 0x00, 0x00, 0x80])
    }

    func testI64Serialization() {
        let ser = BcsSerializer()
        ser.writeI64(-1)
        XCTAssertEqual(ser.toBytes(), [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])

        ser.clear()
        ser.writeI64(9223372036854775807)  // max
        XCTAssertEqual(ser.toBytes(), [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f])

        ser.clear()
        ser.writeI64(Int64.min)  // min
        XCTAssertEqual(ser.toBytes(), [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80])
    }

    func testI128Serialization() throws {
        // -1 in two's complement (all 0xff)
        let negOne = [UInt8](repeating: 0xff, count: 16)
        let ser = BcsSerializer()
        try ser.writeI128(negOne)
        XCTAssertEqual(ser.toBytes(), negOne)
    }

    func testI32Deserialization() throws {
        let des1 = BcsDeserializer([0xff, 0xff, 0xff, 0xff])
        XCTAssertEqual(try des1.readI32(), -1)

        let des2 = BcsDeserializer([0x00, 0x00, 0x00, 0x80])
        XCTAssertEqual(try des2.readI32(), -2147483648)
    }

    func testI64Deserialization() throws {
        let des1 = BcsDeserializer([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
        XCTAssertEqual(try des1.readI64(), -1)

        let des2 = BcsDeserializer([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80])
        XCTAssertEqual(try des2.readI64(), Int64.min)
    }

    func testI128Deserialization() throws {
        let allFf = [UInt8](repeating: 0xff, count: 16)
        let des = BcsDeserializer(allFf)
        XCTAssertEqual(try des.readI128(), allFf)
    }

    func testIntegerDeserialization() throws {
        XCTAssertEqual(try BCS.deserializeU8([0x2a]), 42)
        XCTAssertEqual(try BCS.deserializeU16([0x34, 0x12]), 0x1234)
        XCTAssertEqual(try BCS.deserializeU32([0x78, 0x56, 0x34, 0x12]), 0x1234_5678)
        XCTAssertEqual(try BCS.deserializeU64([0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12]), 0x1234_5678_9ABC_DEF0)
    }

    func testSignedIntegerDeserialization() throws {
        let des1 = BcsDeserializer([0xff])
        XCTAssertEqual(try des1.readI8(), -1)

        let des2 = BcsDeserializer([0x00, 0x80])
        XCTAssertEqual(try des2.readI16(), -32768)
    }

    func testU128Serialization() throws {
        var value = [UInt8](repeating: 0, count: 16)
        value[0] = 0x01

        let ser = BcsSerializer()
        try ser.writeU128(value)
        let bytes = ser.toBytes()

        XCTAssertEqual(bytes.count, 16)
        XCTAssertEqual(bytes[0], 0x01)
    }

    func testU256Serialization() throws {
        var value = [UInt8](repeating: 0, count: 32)
        value[0] = 0xff
        value[31] = 0x01

        let ser = BcsSerializer()
        try ser.writeU256(value)
        let bytes = ser.toBytes()

        XCTAssertEqual(bytes.count, 32)
        XCTAssertEqual(bytes[0], 0xff)
        XCTAssertEqual(bytes[31], 0x01)
    }
}

// MARK: - String and Bytes Tests

final class StringAndBytesTests: XCTestCase {

    func testStringSerialization() throws {
        XCTAssertEqual(try BCS.serializeString(""), [0x00])
        XCTAssertEqual(try BCS.serializeString("hello"), [0x05, 0x68, 0x65, 0x6c, 0x6c, 0x6f])
    }

    func testStringDeserialization() throws {
        XCTAssertEqual(try BCS.deserializeString([0x00]), "")
        XCTAssertEqual(try BCS.deserializeString([0x05, 0x68, 0x65, 0x6c, 0x6c, 0x6f]), "hello")
    }

    func testInvalidUtf8() {
        // Length 2, invalid UTF-8 bytes
        XCTAssertThrowsError(try BCS.deserializeString([0x02, 0xff, 0xfe])) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .invalidUtf8)
        }
    }

    func testBytesSerialization() throws {
        let input: [UInt8] = [0x01, 0x02, 0x03]
        let bytes = try BCS.serializeBytes(input)
        XCTAssertEqual(bytes, [0x03, 0x01, 0x02, 0x03])
    }

    func testBytesDeserialization() throws {
        let bytes = try BCS.deserializeBytes([0x03, 0x01, 0x02, 0x03])
        XCTAssertEqual(bytes, [0x01, 0x02, 0x03])
    }

    func testBytesToHex() {
        XCTAssertEqual(BCS.bytesToHex([0x01, 0x02, 0xab, 0xcd]), "0102abcd")
    }

    func testHexToBytes() {
        XCTAssertEqual(BCS.hexToBytes("0102abcd"), [0x01, 0x02, 0xab, 0xcd])
        XCTAssertEqual(BCS.hexToBytes(""), [])
        XCTAssertNil(BCS.hexToBytes("0g"))  // Invalid hex
    }
}

// MARK: - Composite Type Tests

final class CompositeTypeTests: XCTestCase {

    func testOptionSomeSerialization() throws {
        let ser = BcsSerializer()
        try ser.writeOption(UInt8(42)) { s, v in s.writeU8(v) }
        XCTAssertEqual(ser.toBytes(), [0x01, 0x2a])
    }

    func testOptionNoneSerialization() throws {
        let ser = BcsSerializer()
        try ser.writeOption(nil as UInt8?) { s, v in s.writeU8(v) }
        XCTAssertEqual(ser.toBytes(), [0x00])
    }

    func testOptionSomeDeserialization() throws {
        let des = BcsDeserializer([0x01, 0x2a])
        let opt = try des.readOption { d in try d.readU8() }
        XCTAssertEqual(opt, 42)
    }

    func testOptionNoneDeserialization() throws {
        let des = BcsDeserializer([0x00])
        let opt: UInt8? = try des.readOption { d in try d.readU8() }
        XCTAssertNil(opt)
    }

    func testOptionInvalidTag() {
        let des = BcsDeserializer([0x02])
        XCTAssertThrowsError(try des.readOption { d in try d.readU8() }) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .invalidOption(0x02))
        }
    }

    func testVectorEmptySerialization() throws {
        let ser = BcsSerializer()
        try ser.writeVector([UInt8]()) { s, v in s.writeU8(v) }
        XCTAssertEqual(ser.toBytes(), [0x00])
    }

    func testVectorU8Serialization() throws {
        let ser = BcsSerializer()
        try ser.writeVector([UInt8(1), 2, 3]) { s, v in s.writeU8(v) }
        XCTAssertEqual(ser.toBytes(), [0x03, 0x01, 0x02, 0x03])
    }

    func testVectorU16Serialization() throws {
        let ser = BcsSerializer()
        try ser.writeVector([UInt16(1), 2, 3]) { s, v in s.writeU16(v) }
        XCTAssertEqual(ser.toBytes(), [0x03, 0x01, 0x00, 0x02, 0x00, 0x03, 0x00])
    }

    func testVectorDeserialization() throws {
        let des = BcsDeserializer([0x03, 0x01, 0x02, 0x03])
        let vec = try des.readVector { d in try d.readU8() }
        XCTAssertEqual(vec, [1, 2, 3])
    }

    func testMapSerialization() throws {
        let ser = BcsSerializer()
        let map: [UInt8: UInt8] = [1: 10, 2: 20, 3: 30]
        try ser.writeMap(map, keySerializer: { s, k in s.writeU8(k) }, valueSerializer: { s, v in s.writeU8(v) })

        // Map should be sorted by key
        XCTAssertEqual(ser.toBytes(), [0x03, 0x01, 0x0a, 0x02, 0x14, 0x03, 0x1e])
    }

    func testMapDeserialization() throws {
        // 3 entries: (1, 10), (2, 20), (3, 30)
        let des = BcsDeserializer([0x03, 0x01, 0x0a, 0x02, 0x14, 0x03, 0x1e])
        let map = try des.readMap(
            keyDeserializer: { d in try d.readU8() },
            valueDeserializer: { d in try d.readU8() }
        )

        XCTAssertEqual(map.count, 3)
        XCTAssertEqual(map[1], 10)
        XCTAssertEqual(map[2], 20)
        XCTAssertEqual(map[3], 30)
    }

    func testMapNonCanonicalOrder() {
        // Keys out of order: 2, 1
        let des = BcsDeserializer([0x02, 0x02, 0x14, 0x01, 0x0a])
        XCTAssertThrowsError(
            try des.readMap(
                keyDeserializer: { d in try d.readU8() },
                valueDeserializer: { d in try d.readU8() }
            )
        ) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .nonCanonicalMap)
        }
    }

    func testMapDuplicateKeys() {
        // Duplicate key: 1, 1
        let des = BcsDeserializer([0x02, 0x01, 0x0a, 0x01, 0x14])
        XCTAssertThrowsError(
            try des.readMap(
                keyDeserializer: { d in try d.readU8() },
                valueDeserializer: { d in try d.readU8() }
            )
        ) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .duplicateMapKey)
        }
    }
}

// MARK: - Error and Round-trip Tests

final class ErrorAndRoundTripTests: XCTestCase {

    func testUnexpectedEof() {
        let des = BcsDeserializer([0x01])  // Only 1 byte, need 2 for u16
        XCTAssertThrowsError(try des.readU16()) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .unexpectedEof)
        }
    }

    func testRemainingInput() {
        let des = BcsDeserializer([0x01, 0x02])  // Extra byte
        _ = try? des.readU8()
        XCTAssertThrowsError(try des.checkEnd()) { error in
            guard let bcsError = error as? BcsError else {
                XCTFail("Expected BcsError")
                return
            }
            XCTAssertEqual(bcsError.type, .remainingInput(1))
        }
    }

    func testRoundTripU64() throws {
        let original: UInt64 = 0x1234_5678_9ABC_DEF0
        let bytes = BCS.serializeU64(original)
        let result = try BCS.deserializeU64(bytes)
        XCTAssertEqual(result, original)
    }

    func testRoundTripString() throws {
        let original = "Hello, BCS! 你好世界"
        let bytes = try BCS.serializeString(original)
        let result = try BCS.deserializeString(bytes)
        XCTAssertEqual(result, original)
    }

    func testRoundTripComplex() throws {
        // Serialize: (u8, string, vector<u16>)
        let ser = BcsSerializer()
        ser.writeU8(42)
        try ser.writeString("test")
        try ser.writeVector([UInt16(100), 200, 300]) { s, v in s.writeU16(v) }
        let bytes = ser.toBytes()

        // Deserialize
        let des = BcsDeserializer(bytes)
        XCTAssertEqual(try des.readU8(), 42)
        XCTAssertEqual(try des.readString(), "test")
        let vec = try des.readVector { d in try d.readU16() }
        XCTAssertEqual(vec, [100, 200, 300])
        try des.checkEnd()
    }
}
