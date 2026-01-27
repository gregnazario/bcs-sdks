# BCS Swift SDK

A Swift implementation of Binary Canonical Serialization (BCS).

## Features

- **Pure Swift**: No external dependencies
- **Cross-platform**: macOS, iOS, tvOS, watchOS, Linux
- **Type-safe**: Leverages Swift's strong type system
- **Fluent API**: Method chaining for serialization
- **Comprehensive**: Supports all BCS types including u128/u256

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bcs-sdks/bcs-sdks", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "BCS", package: "bcs-sdks")
    ]
)
```

### Xcode

1. File → Add Package Dependencies
2. Enter: `https://github.com/bcs-sdks/bcs-sdks`
3. Select the BCS library

## Quick Start

```swift
import BCS

// Serialize
let ser = BcsSerializer()
ser.writeU64(12345)
try ser.writeString("hello")
ser.writeBool(true)
let bytes = ser.toBytes()

// Deserialize
let des = BcsDeserializer(bytes)
let num = try des.readU64()
let str = try des.readString()
let flag = try des.readBool()
try des.checkEnd()  // Ensure all bytes consumed
```

## Supported Types

| BCS Type | Swift Type | Serialize | Deserialize |
|----------|------------|-----------|-------------|
| bool | `Bool` | `writeBool()` | `readBool()` |
| u8 | `UInt8` | `writeU8()` | `readU8()` |
| u16 | `UInt16` | `writeU16()` | `readU16()` |
| u32 | `UInt32` | `writeU32()` | `readU32()` |
| u64 | `UInt64` | `writeU64()` | `readU64()` |
| u128 | `[UInt8]` (16 bytes) | `writeU128()` | `readU128()` |
| u256 | `[UInt8]` (32 bytes) | `writeU256()` | `readU256()` |
| i8 | `Int8` | `writeI8()` | `readI8()` |
| i16 | `Int16` | `writeI16()` | `readI16()` |
| i32 | `Int32` | `writeI32()` | `readI32()` |
| i64 | `Int64` | `writeI64()` | `readI64()` |
| i128 | `[UInt8]` (16 bytes) | `writeI128()` | `readI128()` |
| i256 | `[UInt8]` (32 bytes) | `writeI256()` | `readI256()` |
| string | `String` | `writeString()` | `readString()` |
| bytes | `[UInt8]` | `writeBytes()` | `readBytes()` |
| option | `Optional<T>` | `writeOption()` | `readOption()` |
| vector | `[T]` | `writeVector()` | `readVector()` |
| map | `[K: V]` | `writeMap()` | `readMap()` |

## Complex Types

### Options

```swift
let ser = BcsSerializer()

// Some value
try ser.writeOption(UInt32(42)) { s, v in s.writeU32(v) }

// None
try ser.writeOption(nil as UInt32?) { s, v in s.writeU32(v) }

// Deserialize
let des = BcsDeserializer(ser.toBytes())
let opt1 = try des.readOption { d in try d.readU32() }  // Optional(42)
let opt2: UInt32? = try des.readOption { d in try d.readU32() }  // nil
```

### Vectors

```swift
let ser = BcsSerializer()
try ser.writeVector([UInt16(100), 200, 300]) { s, v in s.writeU16(v) }

// Deserialize
let des = BcsDeserializer(ser.toBytes())
let vec = try des.readVector { d in try d.readU16() }  // [100, 200, 300]
```

### Maps

```swift
let ser = BcsSerializer()
let scores: [String: UInt64] = ["alice": 100, "bob": 200]
try ser.writeMap(
    scores,
    keySerializer: { s, k in try s.writeString(k) },
    valueSerializer: { s, v in s.writeU64(v) }
)

// Deserialize
let des = BcsDeserializer(ser.toBytes())
let result = try des.readMap(
    keyDeserializer: { d in try d.readString() },
    valueDeserializer: { d in try d.readU64() }
)
```

### Structs

```swift
struct Person {
    let name: String
    let age: UInt32
    let email: String?
}

extension Person {
    func serialize(to ser: BcsSerializer) throws {
        try ser.enterContainer()
        try ser.writeString(name)
        ser.writeU32(age)
        try ser.writeOption(email) { s, e in try s.writeString(e) }
        ser.leaveContainer()
    }

    static func deserialize(from des: BcsDeserializer) throws -> Person {
        try des.enterContainer()
        let name = try des.readString()
        let age = try des.readU32()
        let email = try des.readOption { d in try d.readString() }
        des.leaveContainer()
        return Person(name: name, age: age, email: email)
    }
}
```

### Enums

```swift
enum Message {
    case text(String)
    case image(data: [UInt8], width: UInt32, height: UInt32)
    case file(name: String, data: [UInt8])
}

extension Message {
    func serialize(to ser: BcsSerializer) throws {
        try ser.enterContainer()
        switch self {
        case .text(let content):
            ser.writeVariantIndex(0)
            try ser.writeString(content)
        case .image(let data, let width, let height):
            ser.writeVariantIndex(1)
            try ser.writeBytes(data)
            ser.writeU32(width)
            ser.writeU32(height)
        case .file(let name, let data):
            ser.writeVariantIndex(2)
            try ser.writeString(name)
            try ser.writeBytes(data)
        }
        ser.leaveContainer()
    }
}
```

## Error Handling

All errors are thrown as `BcsError`:

```swift
do {
    let des = BcsDeserializer(data)
    let value = try des.readU64()
} catch let error as BcsError {
    print("BCS error: \(error.message)")
    
    switch error.type {
    case .unexpectedEof:
        // Handle EOF
    case .invalidBoolean(let value):
        // Handle invalid boolean
    case .invalidUtf8:
        // Handle invalid UTF-8
    default:
        break
    }
}
```

## ULEB128 Utilities

Direct access to ULEB128 encoding/decoding:

```swift
import BCS

// Encode
let encoded = Uleb128.encode(300)

// Decode
let (value, bytesRead) = try Uleb128.decode(encoded)

// Get encoded size
let size = Uleb128.encodedSize(300)
```

## Hex Utilities

```swift
// Bytes to hex
let hex = BCS.bytesToHex([0x01, 0x02, 0xab])  // "0102ab"

// Hex to bytes
let bytes = BCS.hexToBytes("0102ab")  // [0x01, 0x02, 0xab]
```

## Development

### Building

```bash
make build
```

### Testing

```bash
make test
```

### Formatting

```bash
make format        # Format code
make format-check  # Check formatting (CI)
```

### Linting

```bash
make lint          # Run SwiftLint
```

### Requirements

- Swift 5.7+
- swift-format (for formatting): `brew install swift-format`
- SwiftLint (for linting): `brew install swiftlint`

## License

Apache-2.0
