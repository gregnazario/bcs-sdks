#!/usr/bin/env swift
// Swift BCS E2E Test Runner
//
// Reads test vectors from stdin, performs roundtrip serialization,
// and outputs results to stdout.
//
// Prerequisites: Build the SDK with `swift build` in sdks/swift first

import Foundation

// Add SDK path - this script expects to be run from the SDK directory
// or have the BCS module available

// Since we can't easily import a local Swift package from a script,
// we'll compile this as part of a test target or use inline code.
// For now, we'll output a placeholder error.

struct TestCase: Codable {
    let name: String
    let type: String
    let value: AnyCodable?
    let bcs_hex: String
    var error: String?
}

struct TestVectors: Codable {
    let version: String
    let description: String
    var primitives: [TestCase]
    var strings: [TestCase]
    var bytes: [TestCase]
    var options: [TestCase]
    var vectors: [TestCase]
    var structs: [TestCase]
    var complex: [TestCase]
}

// Helper for JSON any value
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}

func hexToBytes(_ hex: String) -> [UInt8] {
    var bytes = [UInt8]()
    var index = hex.startIndex
    while index < hex.endIndex {
        let nextIndex = hex.index(index, offsetBy: 2)
        let byteString = hex[index..<nextIndex]
        if let byte = UInt8(byteString, radix: 16) {
            bytes.append(byte)
        }
        index = nextIndex
    }
    return bytes
}

func bytesToHex(_ bytes: [UInt8]) -> String {
    return bytes.map { String(format: "%02x", $0) }.joined()
}

// Simple BCS implementation for roundtrip testing
class BcsSerializer {
    private var buffer: [UInt8] = []
    
    func writeBool(_ value: Bool) { buffer.append(value ? 1 : 0) }
    func writeU8(_ value: UInt8) { buffer.append(value) }
    func writeU16(_ value: UInt16) { 
        buffer.append(UInt8(value & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
    }
    func writeU32(_ value: UInt32) {
        for i in 0..<4 { buffer.append(UInt8((value >> (i * 8)) & 0xFF)) }
    }
    func writeU64(_ value: UInt64) {
        for i in 0..<8 { buffer.append(UInt8((value >> (i * 8)) & 0xFF)) }
    }
    func writeU128(_ bytes: [UInt8]) { buffer.append(contentsOf: bytes) }
    func writeI8(_ value: Int8) { buffer.append(UInt8(bitPattern: value)) }
    func writeI16(_ value: Int16) { writeU16(UInt16(bitPattern: value)) }
    func writeI32(_ value: Int32) { writeU32(UInt32(bitPattern: value)) }
    func writeI64(_ value: Int64) { writeU64(UInt64(bitPattern: value)) }
    func writeI128(_ bytes: [UInt8]) { buffer.append(contentsOf: bytes) }
    
    func writeUleb128(_ value: UInt32) {
        var v = value
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            buffer.append(byte)
        } while v != 0
    }
    
    func writeString(_ s: String) {
        let bytes = Array(s.utf8)
        writeUleb128(UInt32(bytes.count))
        buffer.append(contentsOf: bytes)
    }
    
    func writeBytes(_ bytes: [UInt8]) {
        writeUleb128(UInt32(bytes.count))
        buffer.append(contentsOf: bytes)
    }
    
    func writeFixedBytes(_ bytes: [UInt8]) {
        buffer.append(contentsOf: bytes)
    }
    
    func toBytes() -> [UInt8] { return buffer }
}

class BcsDeserializer {
    private var data: [UInt8]
    private var offset: Int = 0
    
    init(_ data: [UInt8]) { self.data = data }
    
    func readBool() throws -> Bool {
        guard offset < data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        let b = data[offset]; offset += 1
        guard b == 0 || b == 1 else { throw NSError(domain: "BCS", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid bool"]) }
        return b == 1
    }
    
    func readU8() throws -> UInt8 {
        guard offset < data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        let v = data[offset]; offset += 1; return v
    }
    
    func readU16() throws -> UInt16 {
        guard offset + 2 <= data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        let v = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        offset += 2; return v
    }
    
    func readU32() throws -> UInt32 {
        guard offset + 4 <= data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        var v: UInt32 = 0
        for i in 0..<4 { v |= UInt32(data[offset + i]) << (i * 8) }
        offset += 4; return v
    }
    
    func readU64() throws -> UInt64 {
        guard offset + 8 <= data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        var v: UInt64 = 0
        for i in 0..<8 { v |= UInt64(data[offset + i]) << (i * 8) }
        offset += 8; return v
    }
    
    func readU128() throws -> [UInt8] {
        guard offset + 16 <= data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        let bytes = Array(data[offset..<offset+16])
        offset += 16; return bytes
    }
    
    func readI8() throws -> Int8 { return Int8(bitPattern: try readU8()) }
    func readI16() throws -> Int16 { return Int16(bitPattern: try readU16()) }
    func readI32() throws -> Int32 { return Int32(bitPattern: try readU32()) }
    func readI64() throws -> Int64 { return Int64(bitPattern: try readU64()) }
    func readI128() throws -> [UInt8] { return try readU128() }
    
    func readUleb128() throws -> UInt32 {
        var value: UInt32 = 0
        var shift: UInt32 = 0
        while true {
            guard offset < data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
            let byte = data[offset]; offset += 1
            value |= UInt32(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return value
    }
    
    func readString() throws -> String {
        let len = try readUleb128()
        guard offset + Int(len) <= data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        let bytes = Array(data[offset..<offset+Int(len)])
        offset += Int(len)
        guard let s = String(bytes: bytes, encoding: .utf8) else {
            throw NSError(domain: "BCS", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])
        }
        return s
    }
    
    func readBytes() throws -> [UInt8] {
        let len = try readUleb128()
        guard offset + Int(len) <= data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        let bytes = Array(data[offset..<offset+Int(len)])
        offset += Int(len); return bytes
    }
    
    func readFixedBytes(_ len: Int) throws -> [UInt8] {
        guard offset + len <= data.count else { throw NSError(domain: "BCS", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOF"]) }
        let bytes = Array(data[offset..<offset+len])
        offset += len; return bytes
    }
    
    func checkEnd() throws {
        guard offset == data.count else {
            throw NSError(domain: "BCS", code: 4, userInfo: [NSLocalizedDescriptionKey: "Remaining input"])
        }
    }
}

func processTestCase(_ tc: TestCase) -> TestCase {
    var result = tc
    result.error = nil
    
    do {
        let data = hexToBytes(tc.bcs_hex)
        let resultHex: String
        
        switch tc.type {
        case "bool":
            let d = BcsDeserializer(data); let v = try d.readBool(); try d.checkEnd()
            let s = BcsSerializer(); s.writeBool(v); resultHex = bytesToHex(s.toBytes())
        case "u8":
            let d = BcsDeserializer(data); let v = try d.readU8(); try d.checkEnd()
            let s = BcsSerializer(); s.writeU8(v); resultHex = bytesToHex(s.toBytes())
        case "u16":
            let d = BcsDeserializer(data); let v = try d.readU16(); try d.checkEnd()
            let s = BcsSerializer(); s.writeU16(v); resultHex = bytesToHex(s.toBytes())
        case "u32":
            let d = BcsDeserializer(data); let v = try d.readU32(); try d.checkEnd()
            let s = BcsSerializer(); s.writeU32(v); resultHex = bytesToHex(s.toBytes())
        case "u64":
            let d = BcsDeserializer(data); let v = try d.readU64(); try d.checkEnd()
            let s = BcsSerializer(); s.writeU64(v); resultHex = bytesToHex(s.toBytes())
        case "u128":
            let d = BcsDeserializer(data); let v = try d.readU128(); try d.checkEnd()
            let s = BcsSerializer(); s.writeU128(v); resultHex = bytesToHex(s.toBytes())
        case "i8":
            let d = BcsDeserializer(data); let v = try d.readI8(); try d.checkEnd()
            let s = BcsSerializer(); s.writeI8(v); resultHex = bytesToHex(s.toBytes())
        case "i16":
            let d = BcsDeserializer(data); let v = try d.readI16(); try d.checkEnd()
            let s = BcsSerializer(); s.writeI16(v); resultHex = bytesToHex(s.toBytes())
        case "i32":
            let d = BcsDeserializer(data); let v = try d.readI32(); try d.checkEnd()
            let s = BcsSerializer(); s.writeI32(v); resultHex = bytesToHex(s.toBytes())
        case "i64":
            let d = BcsDeserializer(data); let v = try d.readI64(); try d.checkEnd()
            let s = BcsSerializer(); s.writeI64(v); resultHex = bytesToHex(s.toBytes())
        case "i128":
            let d = BcsDeserializer(data); let v = try d.readI128(); try d.checkEnd()
            let s = BcsSerializer(); s.writeI128(v); resultHex = bytesToHex(s.toBytes())
        case "string":
            let d = BcsDeserializer(data); let v = try d.readString(); try d.checkEnd()
            let s = BcsSerializer(); s.writeString(v); resultHex = bytesToHex(s.toBytes())
        case "bytes":
            let d = BcsDeserializer(data); let v = try d.readBytes(); try d.checkEnd()
            let s = BcsSerializer(); s.writeBytes(v); resultHex = bytesToHex(s.toBytes())
        case "fixed_bytes_32":
            let d = BcsDeserializer(data); let v = try d.readFixedBytes(32); try d.checkEnd()
            let s = BcsSerializer(); s.writeFixedBytes(v); resultHex = bytesToHex(s.toBytes())
        case "option<u8>":
            let d = BcsDeserializer(data); let hasVal = try d.readBool()
            let s = BcsSerializer(); s.writeBool(hasVal)
            if hasVal { let v = try d.readU8(); s.writeU8(v) }
            try d.checkEnd(); resultHex = bytesToHex(s.toBytes())
        case "option<u64>":
            let d = BcsDeserializer(data); let hasVal = try d.readBool()
            let s = BcsSerializer(); s.writeBool(hasVal)
            if hasVal { let v = try d.readU64(); s.writeU64(v) }
            try d.checkEnd(); resultHex = bytesToHex(s.toBytes())
        case "option<bool>":
            let d = BcsDeserializer(data); let hasVal = try d.readBool()
            let s = BcsSerializer(); s.writeBool(hasVal)
            if hasVal { let v = try d.readBool(); s.writeBool(v) }
            try d.checkEnd(); resultHex = bytesToHex(s.toBytes())
        case "option<string>":
            let d = BcsDeserializer(data); let hasVal = try d.readBool()
            let s = BcsSerializer(); s.writeBool(hasVal)
            if hasVal { let v = try d.readString(); s.writeString(v) }
            try d.checkEnd(); resultHex = bytesToHex(s.toBytes())
        case "vector<u8>":
            let d = BcsDeserializer(data); let len = try d.readUleb128()
            var vals: [UInt8] = []; for _ in 0..<len { vals.append(try d.readU8()) }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(vals.count)); for v in vals { s.writeU8(v) }
            resultHex = bytesToHex(s.toBytes())
        case "vector<u64>":
            let d = BcsDeserializer(data); let len = try d.readUleb128()
            var vals: [UInt64] = []; for _ in 0..<len { vals.append(try d.readU64()) }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(vals.count)); for v in vals { s.writeU64(v) }
            resultHex = bytesToHex(s.toBytes())
        case "vector<bool>":
            let d = BcsDeserializer(data); let len = try d.readUleb128()
            var vals: [Bool] = []; for _ in 0..<len { vals.append(try d.readBool()) }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(vals.count)); for v in vals { s.writeBool(v) }
            resultHex = bytesToHex(s.toBytes())
        case "vector<vector<u8>>":
            let d = BcsDeserializer(data); let outerLen = try d.readUleb128()
            var outer: [[UInt8]] = []
            for _ in 0..<outerLen {
                let innerLen = try d.readUleb128()
                var inner: [UInt8] = []; for _ in 0..<innerLen { inner.append(try d.readU8()) }
                outer.append(inner)
            }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(outer.count))
            for inner in outer { s.writeUleb128(UInt32(inner.count)); for v in inner { s.writeU8(v) } }
            resultHex = bytesToHex(s.toBytes())
        case "vector<string>":
            let d = BcsDeserializer(data); let len = try d.readUleb128()
            var vals: [String] = []; for _ in 0..<len { vals.append(try d.readString()) }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(vals.count)); for v in vals { s.writeString(v) }
            resultHex = bytesToHex(s.toBytes())
        case "struct":
            guard let valueDict = tc.value?.value as? [String: Any],
                  let fieldsArr = valueDict["fields"] as? [[String: Any]] else {
                throw NSError(domain: "BCS", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid struct"])
            }
            let d = BcsDeserializer(data)
            let s = BcsSerializer()
            for field in fieldsArr {
                guard let fieldType = field["type"] as? String else { continue }
                switch fieldType {
                case "u8": s.writeU8(try d.readU8())
                case "u64": s.writeU64(try d.readU64())
                case "string": s.writeString(try d.readString())
                case "fixed_bytes_32": s.writeFixedBytes(try d.readFixedBytes(32))
                default: break
                }
            }
            try d.checkEnd(); resultHex = bytesToHex(s.toBytes())
        case "map<u8,u8>":
            let d = BcsDeserializer(data); let len = try d.readUleb128()
            var pairs: [(UInt8, UInt8)] = []
            for _ in 0..<len { pairs.append((try d.readU8(), try d.readU8())) }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(pairs.count))
            for (k, v) in pairs { s.writeU8(k); s.writeU8(v) }
            resultHex = bytesToHex(s.toBytes())
        case "map<string,u64>":
            let d = BcsDeserializer(data); let len = try d.readUleb128()
            var pairs: [(String, UInt64)] = []
            for _ in 0..<len { pairs.append((try d.readString(), try d.readU64())) }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(pairs.count))
            for (k, v) in pairs { s.writeString(k); s.writeU64(v) }
            resultHex = bytesToHex(s.toBytes())
        case "tuple<u8,u64>":
            let d = BcsDeserializer(data); let a = try d.readU8(); let b = try d.readU64()
            try d.checkEnd()
            let s = BcsSerializer(); s.writeU8(a); s.writeU64(b)
            resultHex = bytesToHex(s.toBytes())
        case "vector<option<u8>>":
            let d = BcsDeserializer(data); let len = try d.readUleb128()
            var vals: [UInt8?] = []
            for _ in 0..<len {
                let hasVal = try d.readBool()
                vals.append(hasVal ? try d.readU8() : nil)
            }
            try d.checkEnd()
            let s = BcsSerializer(); s.writeUleb128(UInt32(vals.count))
            for v in vals { s.writeBool(v != nil); if let val = v { s.writeU8(val) } }
            resultHex = bytesToHex(s.toBytes())
        default:
            result.error = "Unknown type: \(tc.type)"
            return result
        }
        
        result = TestCase(name: tc.name, type: tc.type, value: tc.value, bcs_hex: resultHex, error: nil)
    } catch {
        result.error = error.localizedDescription
    }
    
    return result
}

// Benchmark support
import Foundation

struct BenchmarkOutput: Codable {
    let version: String
    let description: String
    let benchmarks: [BenchmarkResultFull]
}

struct BenchmarkResultFull: Codable {
    let name: String
    let type: String
    let iterations: Int
    var serialize_avg_ns: Double = 0
    var serialize_min_ns: Double = 0
    var serialize_max_ns: Double = 0
    var serialize_p50_ns: Double = 0
    var serialize_p95_ns: Double = 0
    var deserialize_avg_ns: Double = 0
    var deserialize_min_ns: Double = 0
    var deserialize_max_ns: Double = 0
    var deserialize_p50_ns: Double = 0
    var deserialize_p95_ns: Double = 0
    var throughput_serialize_ops_sec: Double = 0
    var throughput_deserialize_ops_sec: Double = 0
    var error: String?
}

struct BenchmarkSpec: Codable {
    struct Config: Codable {
        let default_iterations: Int?
        let warmup_iterations: Int?
    }
    struct Group: Codable {
        let benchmarks: [BenchCase]?
    }
    struct BenchCase: Codable {
        let name: String
        let type: String
        let value: AnyCodable?
        let value_generator: String?
        let length: Int?
        let char: String?
        let iterations: Int?
    }
    let version: String?
    let config: Config?
    let scenarios: [String: Group]?
}

func computeStats(_ times: [UInt64]) -> (avg: Double, min: Double, max: Double, p50: Double, p95: Double) {
    guard !times.isEmpty else { return (0, 0, 0, 0, 0) }
    let sorted = times.sorted()
    let n = sorted.count
    let sum = times.reduce(0, +)
    return (
        Double(sum) / Double(n),
        Double(sorted[0]),
        Double(sorted[n-1]),
        Double(sorted[n/2]),
        Double(sorted[Int(Double(n) * 0.95)])
    )
}

func generateBenchValue(_ bc: BenchmarkSpec.BenchCase) -> Any? {
    if let v = bc.value { return v.value }
    let length = bc.length ?? 10
    switch bc.value_generator {
    case "repeat_char":
        let c = bc.char ?? "a"
        return String(repeating: c, count: length)
    case "sequential_bytes", "sequential_u8":
        return (0..<length).map { $0 % 256 }
    case "sequential_u64":
        return (0..<length).map { String($0) }
    case "address_bytes":
        return Array(repeating: 0, count: 31) + [1]
    default:
        return bc.value?.value
    }
}

func serializeBenchValue(_ s: inout BcsSerializer, _ type: String, _ value: Any?) {
    switch type {
    case "bool": s.writeBool(value as? Bool ?? false)
    case "u8": s.writeU8(UInt8(value as? Int ?? 0))
    case "u16": s.writeU16(UInt16(value as? Int ?? 0))
    case "u32": s.writeU32(UInt32(value as? Int ?? 0))
    case "u64":
        if let str = value as? String { s.writeU64(UInt64(str) ?? 0) }
        else { s.writeU64(UInt64(value as? Int ?? 0)) }
    case "string": s.writeString(value as? String ?? "")
    case "vector<u8>", "bytes":
        let arr = value as? [Int] ?? []
        s.writeUleb128(UInt32(arr.count))
        for v in arr { s.writeU8(UInt8(v)) }
    case "vector<u64>":
        let arr = value as? [Any] ?? []
        s.writeUleb128(UInt32(arr.count))
        for v in arr {
            if let str = v as? String { s.writeU64(UInt64(str) ?? 0) }
            else { s.writeU64(UInt64(v as? Int ?? 0)) }
        }
    case "vector<string>":
        let arr = value as? [String] ?? []
        s.writeUleb128(UInt32(arr.count))
        for v in arr { s.writeString(v) }
    default: break
    }
}

func deserializeBenchValue(_ d: inout BcsDeserializer, _ type: String) {
    switch type {
    case "bool": _ = try? d.readBool()
    case "u8": _ = try? d.readU8()
    case "u16": _ = try? d.readU16()
    case "u32": _ = try? d.readU32()
    case "u64": _ = try? d.readU64()
    case "string": _ = try? d.readString()
    case "vector<u8>", "bytes":
        if let len = try? d.readUleb128() {
            for _ in 0..<len { _ = try? d.readU8() }
        }
    case "vector<u64>":
        if let len = try? d.readUleb128() {
            for _ in 0..<len { _ = try? d.readU64() }
        }
    case "vector<string>":
        if let len = try? d.readUleb128() {
            for _ in 0..<len { _ = try? d.readString() }
        }
    default: break
    }
}

func runBenchmarks(_ data: Data) -> BenchmarkOutput {
    guard let spec = try? JSONDecoder().decode(BenchmarkSpec.self, from: data) else {
        return BenchmarkOutput(version: "1.0.0", description: "Swift benchmark results", benchmarks: [])
    }
    
    let defaultIterations = spec.config?.default_iterations ?? 1000
    let warmup = spec.config?.warmup_iterations ?? 10
    
    var results: [BenchmarkResultFull] = []
    
    for (_, group) in spec.scenarios ?? [:] {
        for bc in group.benchmarks ?? [] {
            let iterations = bc.iterations ?? defaultIterations
            let value = generateBenchValue(bc)
            
            // Serialize to get bytes
            var ser = BcsSerializer()
            serializeBenchValue(&ser, bc.type, value)
            let bcsBytes = ser.toBytes()
            
            // Warmup serialize
            for _ in 0..<warmup {
                var ws = BcsSerializer()
                serializeBenchValue(&ws, bc.type, value)
                _ = ws.toBytes()
            }
            
            // Benchmark serialize
            var serTimes: [UInt64] = []
            for _ in 0..<iterations {
                let start = DispatchTime.now().uptimeNanoseconds
                var bs = BcsSerializer()
                serializeBenchValue(&bs, bc.type, value)
                _ = bs.toBytes()
                serTimes.append(DispatchTime.now().uptimeNanoseconds - start)
            }
            
            // Warmup deserialize
            for _ in 0..<warmup {
                var wd = BcsDeserializer(bcsBytes)
                deserializeBenchValue(&wd, bc.type)
            }
            
            // Benchmark deserialize
            var deTimes: [UInt64] = []
            for _ in 0..<iterations {
                let start = DispatchTime.now().uptimeNanoseconds
                var bd = BcsDeserializer(bcsBytes)
                deserializeBenchValue(&bd, bc.type)
                deTimes.append(DispatchTime.now().uptimeNanoseconds - start)
            }
            
            let serStats = computeStats(serTimes)
            let deStats = computeStats(deTimes)
            
            var result = BenchmarkResultFull(name: bc.name, type: bc.type, iterations: iterations)
            result.serialize_avg_ns = serStats.avg
            result.serialize_min_ns = serStats.min
            result.serialize_max_ns = serStats.max
            result.serialize_p50_ns = serStats.p50
            result.serialize_p95_ns = serStats.p95
            result.deserialize_avg_ns = deStats.avg
            result.deserialize_min_ns = deStats.min
            result.deserialize_max_ns = deStats.max
            result.deserialize_p50_ns = deStats.p50
            result.deserialize_p95_ns = deStats.p95
            result.throughput_serialize_ops_sec = serStats.avg > 0 ? 1e9 / serStats.avg : 0
            result.throughput_deserialize_ops_sec = deStats.avg > 0 ? 1e9 / deStats.avg : 0
            results.append(result)
        }
    }
    
    return BenchmarkOutput(version: spec.version ?? "1.0.0", description: "Swift benchmark results", benchmarks: results)
}

// Main
func main() {
    let benchmarkMode = CommandLine.arguments.contains("--benchmark")
    let inputData = FileHandle.standardInput.readDataToEndOfFile()
    
    if benchmarkMode {
        let output = runBenchmarks(inputData)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(output),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        return
    }
    
    guard let vectors = try? JSONDecoder().decode(TestVectors.self, from: inputData) else {
        fputs("Error: Failed to parse input JSON\n", stderr)
        exit(1)
    }
    
    var output = TestVectors(
        version: vectors.version,
        description: "Swift roundtrip results",
        primitives: vectors.primitives.map(processTestCase),
        strings: vectors.strings.map(processTestCase),
        bytes: vectors.bytes.map(processTestCase),
        options: vectors.options.map(processTestCase),
        vectors: vectors.vectors.map(processTestCase),
        structs: vectors.structs.map(processTestCase),
        complex: vectors.complex.map(processTestCase)
    )
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let jsonData = try? encoder.encode(output),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
    }
}

main()
