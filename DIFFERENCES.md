# BCS SDK Implementation Differences

This document outlines the key differences in implementation approaches across all 15 BCS SDK implementations.

---

## Table of Contents

1. [API Design Patterns](#api-design-patterns)
2. [Error Handling](#error-handling)
3. [Integer Types & Large Numbers](#integer-types--large-numbers)
4. [String Handling](#string-handling)
5. [Memory Management](#memory-management)
6. [Map Support](#map-support)
7. [Container Depth Tracking](#container-depth-tracking)
8. [Batch Operations](#batch-operations)
9. [Language-Specific Features](#language-specific-features)
10. [Performance Characteristics](#performance-characteristics)

---

## API Design Patterns

### Fluent Builder / Method Chaining

SDKs that return `this`/`self` for chaining write operations:

| SDK | Example |
|-----|---------|
| **C++** | `ser.write_u32(42).write_string("hello").write_bool(true);` |
| **C#** | `ser.WriteU32(42).WriteString("hello").WriteBool(true);` |
| **Dart** | `ser..writeU32(42)..writeString("hello")..writeBool(true);` |
| **Java** | `ser.writeU32(42).writeString("hello").writeBool(true);` |
| **Kotlin** | `ser.writeU32(42).writeString("hello").writeBool(true)` |
| **Python** | `ser.write_u32(42).write_string("hello").write_bool(True)` |
| **Ruby** | `ser.write_u32(42).write_string("hello").write_bool(true)` |
| **Swift** | `ser.writeU32(42).writeString("hello").writeBool(true)` |
| **TypeScript** | `ser.writeU32(42).writeString("hello").writeBool(true);` |

### Procedural (Separate State)

| SDK | Example |
|-----|---------|
| **C** | `bcs_write_u32(&ser, 42); bcs_write_string(&ser, "hello");` |
| **Go** | `ser.WriteU32(42); ser.WriteString("hello");` (returns `*Serializer`) |

### Functional (Tuple/Result Returns)

| SDK | Example |
|-----|---------|
| **Elixir** | `{:ok, ser} = Serializer.write_u32(ser, 42)` |
| **OCaml** | `Serializer.write_u32 ser 42; Serializer.write_string ser "hello"` |
| **Rust** | Uses `serde` derive macros: `#[derive(Serialize, Deserialize)]` |

### Comptime Generic

| SDK | Example |
|-----|---------|
| **Zig** | `try ser.writeInt(u32, 42); try ser.writeString("hello");` |

---

## Error Handling

### Exceptions / Panics

| SDK | Error Type | Example |
|-----|------------|---------|
| **C++** | `bcs::Error` | `throw bcs::Error(bcs::ErrorType::INVALID_BOOLEAN, "...")` |
| **C#** | `BcsException` | `throw BcsException.InvalidBoolean(value)` |
| **Dart** | `BcsException` | `throw BcsException.invalidBoolean(value)` |
| **Java** | `BcsError` (RuntimeException) | `throw BcsError.invalidBoolean(value)` |
| **Kotlin** | `BcsError` (RuntimeException) | `throw BcsError.invalidBoolean(value)` |
| **Python** | `BcsError` | `raise BcsError.invalid_boolean(value)` |
| **Ruby** | `Bcs::Error` | `raise Bcs::InvalidBooleanError.new(value)` |
| **Swift** | `BcsError` (enum) | `throw BcsError.invalidBoolean(value)` |
| **TypeScript** | `BcsError` | `throw BcsError.invalidBoolean(value)` |
| **Go** | Panic (idiomatic) | `panic(NewInvalidBoolean(value))` |

### Return Codes / Result Types

| SDK | Pattern | Example |
|-----|---------|---------|
| **C** | Error codes | `bcs_error_t err = bcs_read_bool(&des, &value);` |
| **Rust** | `Result<T, E>` | `let value: u32 = deserializer.deserialize_u32()?;` |
| **Elixir** | `{:ok, _}` / `{:error, _}` | `{:ok, value} = Deserializer.read_u32(des)` |
| **Zig** | Error unions | `const value = try des.readU32();` |
| **OCaml** | Exceptions | `exception Bcs_error of error_type` |

---

## Integer Types & Large Numbers

### Native Support for All Types

| SDK | u8-u64 | i8-i64 | u128 | i128 | u256 | i256 |
|-----|--------|--------|------|------|------|------|
| **Rust** | ✅ Native | ✅ Native | ✅ Native | ✅ Native | ❌ | ❌ |
| **Zig** | ✅ Native | ✅ Native | ✅ Native | ✅ Native | ⚠️ [32]u8 | ⚠️ [32]u8 |

### BigInteger/BigInt for Large Types

| SDK | Library | u128+ Representation |
|-----|---------|---------------------|
| **C#** | `System.Numerics.BigInteger` | BigInteger |
| **Dart** | Native `BigInt` | BigInt |
| **Java** | `java.math.BigInteger` | BigInteger |
| **Kotlin** | `java.math.BigInteger` | BigInteger (extension functions) |
| **Python** | Native `int` (arbitrary precision) | int |
| **Ruby** | Native Integer (arbitrary precision) | Integer |
| **TypeScript** | Native `bigint` | bigint |
| **Elixir** | Native integer (arbitrary precision) | integer |

### Byte Array Representation

| SDK | u128/u256 Representation | Notes |
|-----|-------------------------|-------|
| **C** | `uint8_t[16]` / `uint8_t[32]` | Little-endian byte arrays |
| **C++** | `std::array<uint8_t, 16/32>` | With conversion helpers |
| **Swift** | `Data` / `[UInt8]` | Little-endian byte arrays |
| **OCaml** | `bytes` | Little-endian byte sequences |
| **Go** | `*big.Int` | Pointer to big.Int struct |

---

## String Handling

### UTF-8 Validation

All SDKs validate UTF-8 on deserialization. Implementation approaches:

| SDK | Validation Method |
|-----|-------------------|
| **C** | Custom `bcs_is_valid_utf8()` function |
| **C++** | Custom validation loop |
| **C#** | `Encoding.UTF8.GetString()` throws on invalid |
| **Dart** | `utf8.decode()` with strict mode |
| **Elixir** | `String.valid?/1` |
| **Go** | `utf8.Valid()` from standard library |
| **Java** | `CharsetDecoder` with REPORT action |
| **Kotlin** | Re-encode and compare (strict validation) |
| **OCaml** | Custom RFC 3629 validation |
| **Python** | `bytes.decode('utf-8', errors='strict')` |
| **Ruby** | `force_encoding(Encoding::UTF_8).valid_encoding?` |
| **Rust** | `std::str::from_utf8()` |
| **Swift** | `String(data:encoding:)` returns nil on invalid |
| **TypeScript** | `TextDecoder` with fatal mode |
| **Zig** | `std.unicode.utf8ValidateSlice()` |

---

## Memory Management

### Automatic Buffer Growth

| SDK | Strategy |
|-----|----------|
| **C** | Optional dynamic allocation with `bcs_serializer_init_dynamic()` |
| **C++** | `std::vector<uint8_t>` auto-grows |
| **C#** | `byte[]` with manual resize |
| **Dart** | `BytesBuilder` or pre-allocated `Uint8List` |
| **Go** | `bytes.Buffer` auto-grows |
| **Java** | `ByteArrayOutputStream` auto-grows |
| **Kotlin** | `ByteArrayOutputStream` auto-grows |
| **Python** | `bytearray` auto-grows |
| **Ruby** | Binary string (`String.b`) auto-grows |
| **Rust** | `Vec<u8>` auto-grows |
| **Swift** | `Data` auto-grows |
| **TypeScript** | `Uint8Array` with manual resize |
| **Zig** | `ArrayList(u8)` with allocator |

### Object Pooling

| SDK | Pooling Support |
|-----|-----------------|
| **Go** | `AcquireSerializer()` / `ReleaseSerializer()` with `sync.Pool` |
| **Go** | `AcquireDeserializer()` / `ReleaseDeserializer()` |
| **C++** | Manual with `reset()` method |
| **Others** | Generally just `reset()` for reuse |

### Zero-Copy Deserialization

| SDK | Zero-Copy Support |
|-----|-------------------|
| **C++** | `read_bytes_view()` returns `std::span` |
| **Dart** | `readBytesView()` returns `Uint8List` view |
| **Rust** | Serde's `borrow` attribute |
| **Swift** | Returns `Data` subrange (copy-on-write) |
| **Zig** | Returns slices of input |

---

## Map Support

### Full Map API

| SDK | Serialization | Deserialization | Key Validation |
|-----|---------------|-----------------|----------------|
| **C++** | `write_map()` | `read_map()` | ✅ Sorted + duplicates |
| **Dart** | `writeMap()` | `readMap()` | ✅ Sorted + duplicates |
| **Elixir** | `Serializer.write_map()` | `Deserializer.read_map()` | ✅ Sorted + duplicates |
| **Java** | `writeMap()` | `readMap()` | ✅ Sorted + duplicates |
| **Kotlin** | `writeMap()` | `readMap()` | ✅ Sorted + duplicates |
| **Python** | `write_map()` | `read_map()` | ✅ Sorted + duplicates |
| **Ruby** | `write_map()` | `read_map()` | ✅ Sorted + duplicates |
| **Rust** | `BTreeMap` via Serde | Auto via Serde | ✅ BTreeMap is sorted |
| **Swift** | `writeMap()` | `readMap()` | ✅ Sorted + duplicates |
| **TypeScript** | `writeMap()` | `readMap()` | ✅ Sorted + duplicates |

### Partial/Helper Map Support

| SDK | Support Level | Notes |
|-----|---------------|-------|
| **C** | Helpers only | `bcs_write_map_len()`, `bcs_compare_bytes()` |
| **C#** | Length only | `WriteMapLength()`, manual key handling |
| **Go** | Sort helper | `SortMapEntries()`, `WriteMapLen()` |
| **OCaml** | Full | `write_map`, `read_map` with validation |
| **Zig** | Helpers only | `writeMapLen()`, `readMapLen()`, `compareBytes()` |

---

## Container Depth Tracking

All SDKs enforce `MAX_CONTAINER_DEPTH = 500`:

| SDK | Methods |
|-----|---------|
| **C** | `bcs_enter_struct()`, `bcs_leave_struct()`, `bcs_write_variant_index()` |
| **C++** | `enter_struct()`, `leave_struct()`, `enter_enum()`, `leave_enum()` |
| **C#** | `EnterStruct()`, `LeaveStruct()`, `EnterEnum()`, `LeaveEnum()` |
| **Dart** | `enterStruct()`, `leaveStruct()`, `enterEnum()`, `leaveEnum()` |
| **Elixir** | `enter_struct/1`, `leave_struct/1`, `enter_enum/2`, `leave_enum/1` |
| **Go** | `EnterStruct()`, `LeaveStruct()`, `EnterEnum()`, `LeaveEnum()` |
| **Java** | `enterStruct()`, `leaveStruct()`, `enterEnum()`, `leaveEnum()` |
| **Kotlin** | `enterStruct()`, `leaveStruct()`, `enterEnum()`, `leaveEnum()` |
| **OCaml** | `enter_struct`, `leave_struct`, `write_variant_index`, `leave_enum` |
| **Python** | `enter_struct()`, `leave_struct()`, `enter_enum()`, `leave_enum()` |
| **Ruby** | `enter_struct`, `leave_struct`, `enter_enum`, `leave_enum` |
| **Rust** | Automatic via Serde |
| **Swift** | `enterStruct()`, `leaveStruct()`, `enterEnum()`, `leaveEnum()` |
| **TypeScript** | `enterStruct()`, `leaveStruct()`, `enterEnum()`, `leaveEnum()` |
| **Zig** | `enterStruct()`, `leaveStruct()`, `writeVariantIndex()`, `leaveEnum()` |

---

## Batch Operations

### Optimized Vector Writes

| SDK | Batch Methods |
|-----|---------------|
| **C++** | `write_u8_vector()`, `write_u16_vector()`, etc. |
| **Dart** | `writeU8List()`, `writeU16List()`, etc. |
| **Go** | `WriteU8Slice()`, `WriteU16Slice()`, etc. |
| **Kotlin** | `writeU8Vector()`, `writeU16Vector()`, etc. |
| **Python** | `write_u8_list()`, `write_u16_list()`, etc. |
| **Ruby** | `write_u8_array`, `write_u16_array`, etc. |
| **Zig** | `writeU8Vector()`, `writeIntVector(T, values)` |

---

## Language-Specific Features

### C

```c
// Compiler hints for branch prediction
#define BCS_LIKELY(x) __builtin_expect(!!(x), 1)
#define BCS_UNLIKELY(x) __builtin_expect(!!(x), 0)

// Hot path attribute
#define BCS_HOT __attribute__((hot))
```

### C++

```cpp
// Template metaprogramming for generic integer writes
template<typename T>
void write_int(T value);

// Zero-copy view
std::span<const uint8_t> read_bytes_view(size_t len);
```

### Dart

```dart
// Zero-copy byte view
Uint8List readBytesView(int length);

// Optimized u64 write for int values
void writeU64Int(int value);  // Avoids BigInt overhead
```

### Go

```go
// Object pooling
ser := bcs.AcquireSerializer()
defer bcs.ReleaseSerializer(ser)

// Pre-computed constants cached via sync.Once
var modulus128 *big.Int  // Computed once, reused
```

### Kotlin

```kotlin
// DSL-style syntax
val bytes = bcsSerialize {
    writeU8(42)
    writeString("hello")
    writeList(listOf(1, 2, 3)) { writeU8(it) }
}

// Infix operators
ser write true
ser write "hello"
```

### Python

```python
# Configurable maximum allocation (defense-in-depth)
deserializer = Deserializer(data, max_alloc=1_000_000)

# memoryview for zero-copy
view = deserializer.read_bytes_view(length)
```

### Ruby

```ruby
# Binary string buffer
@buffer = String.new(encoding: Encoding::BINARY, capacity: 256)

# Pack/unpack for efficient integer handling
@buffer << [value].pack('Q<')  # Little-endian u64
```

### Rust

```rust
// Serde integration - automatic serialization
#[derive(Serialize, Deserialize)]
struct MyStruct {
    field1: u64,
    field2: String,
}

// Zero-copy deserialization
#[derive(Deserialize)]
struct Borrowed<'a> {
    #[serde(borrow)]
    data: &'a [u8],
}
```

### Swift

```swift
// @inlinable for performance-critical methods
@inlinable
public mutating func writeU64(_ value: UInt64) {
    // Implementation
}

// Zero-copy slices (copy-on-write)
func readBytes(_ length: Int) -> Data  // Returns subrange
```

### Zig

```zig
// Comptime generics
pub fn writeInt(self: *Self, comptime T: type, value: T) Error!void {
    // Single implementation for all integer types
}

// Error unions instead of exceptions
const value = try des.readU32();  // Propagates error
```

---

## Performance Characteristics

### Serialization Speed (relative to Rust baseline)

| Tier | SDKs | Relative Speed |
|------|------|----------------|
| **Fastest** | Rust, C, C++ | 1.0x - 1.2x |
| **Fast** | Go | ~10x |
| **Medium** | C#, Kotlin, Python | 30x - 80x |
| **Slower** | TypeScript, Java, Elixir, Dart | 90x - 110x |
| **Slowest** | Ruby, Swift | 400x - 850x |

*Note: See BENCHMARK_REPORT.md for detailed performance data*

### Deserialization Speed

| Tier | SDKs | Notes |
|------|------|-------|
| **Fastest** | C, C++, Rust | Direct memory access |
| **Fast** | Go, Java, Kotlin | JIT compilation benefits |
| **Medium** | C#, TypeScript, Dart | Interpreted overhead |
| **Slower** | Python, Ruby, Swift | Dynamic typing overhead |

### Memory Efficiency

| Approach | SDKs | Trade-offs |
|----------|------|------------|
| **Stack allocated** | C, Zig | No heap allocation, fixed size |
| **Pre-allocated** | C++, Rust | Predictable, may over-allocate |
| **Growing buffer** | Most others | Flexible, reallocation cost |
| **Object pooling** | Go | Reduces GC pressure |

---

## Summary Table

| Feature | C | C++ | C# | Dart | Elixir | Go | Java | Kotlin | OCaml | Python | Ruby | Rust | Swift | TS | Zig |
|---------|---|-----|----|----|--------|----|----|--------|-------|--------|------|------|-------|----|----|
| Fluent API | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| Exceptions | ❌ | ✅ | ✅ | ✅ | ❌ | ✅* | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| Result types | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Native u128 | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| u256/i256 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Object pool | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Zero-copy | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Serde | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Full maps | ⚠️ | ✅ | ⚠️ | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| Batch ops | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |

**Legend:** ✅ = Yes, ❌ = No, ⚠️ = Partial (helpers only)

*Go uses panics, which are similar to exceptions

---

*Document generated from comprehensive SDK analysis - 2026-01-28*
