# Binary Canonical Serialization (BCS) Specification

**Version:** 1.0.0  
**Status:** Draft  
**Last Updated:** 2026-01-26

## Abstract

Binary Canonical Serialization (BCS) is a deterministic binary serialization format designed for blockchain applications. BCS guarantees that every value of a given type has exactly one valid serialized representation, enabling reliable cryptographic hashing and signature verification.

This specification uses RFC 2119 keywords (SHALL, SHOULD, MAY, etc.) to indicate requirement levels.

## Table of Contents

1. [Introduction](#1-introduction)
2. [Conventions](#2-conventions)
3. [Primitive Types](#3-primitive-types)
4. [ULEB128 Encoding](#4-uleb128-encoding)
5. [Composite Types](#5-composite-types)
6. [Constraints](#6-constraints)
7. [Error Handling](#7-error-handling)
8. [Security Considerations](#8-security-considerations)

---

## 1. Introduction

### 1.1 Purpose

BCS was developed for the Diem (formerly Libra) blockchain with the following goals:

- Provide compact binary representations with good performance
- Support a rich set of data types
- Enforce canonical serialization (one-to-one mapping between values and bytes)
- Mitigate risks from malicious inputs through well-defined limits

### 1.2 Scope

This specification defines the serialization format for:

- Unsigned integers: u8, u16, u32, u64, u128, u256
- Signed integers: i8, i16, i32, i64, i128, i256
- Booleans
- Byte arrays and strings
- Optional values
- Sequences (variable and fixed length)
- Structures
- Enumerations
- Maps

### 1.3 Non-Goals

BCS explicitly does NOT support:

- Floating-point numbers (f32, f64)
- Single Unicode characters (char)
- Sets (use sorted maps or vectors instead)
- Self-describing formats (schema must be known ahead of time)

---

## 2. Conventions

### 2.1 Terminology

The key words "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

- **Serialization**: Converting an in-memory value to a byte sequence
- **Deserialization**: Converting a byte sequence back to an in-memory value
- **Canonical**: Having exactly one valid representation

### 2.2 Byte Order

All multi-byte integers SHALL be serialized in **little-endian** byte order.

### 2.3 Notation

- `0x` prefix indicates hexadecimal values
- `[a, b, c]` indicates a byte sequence
- `||` indicates byte concatenation

---

## 3. Primitive Types

### 3.1 Booleans

A boolean value SHALL be serialized as a single byte:

| Value | Serialized |
|-------|------------|
| false | `0x00` |
| true  | `0x01` |

**Requirements:**

- Serializers SHALL encode `false` as `0x00` and `true` as `0x01`
- Deserializers SHALL reject any byte value other than `0x00` or `0x01`
- Deserializers SHALL NOT treat non-zero values as `true`

### 3.2 Unsigned Integers

Unsigned integers SHALL be serialized as fixed-width little-endian bytes:

| Type | Width | Min Value | Max Value |
|------|-------|-----------|-----------|
| u8   | 1 byte | 0 | 255 (2^8 - 1) |
| u16  | 2 bytes | 0 | 65,535 (2^16 - 1) |
| u32  | 4 bytes | 0 | 4,294,967,295 (2^32 - 1) |
| u64  | 8 bytes | 0 | 18,446,744,073,709,551,615 (2^64 - 1) |
| u128 | 16 bytes | 0 | 2^128 - 1 |
| u256 | 32 bytes | 0 | 2^256 - 1 |

**Examples:**

| Type | Value | Serialized Bytes |
|------|-------|------------------|
| u8 | 1 | `[0x01]` |
| u8 | 255 | `[0xFF]` |
| u16 | 256 | `[0x00, 0x01]` |
| u16 | 0x1234 | `[0x34, 0x12]` |
| u32 | 0x12345678 | `[0x78, 0x56, 0x34, 0x12]` |
| u64 | 1 | `[0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]` |

**Requirements:**

- Serializers SHALL use exactly the specified number of bytes
- Serializers SHALL use little-endian byte order
- Deserializers SHALL read exactly the specified number of bytes
- Deserializers SHALL fail if insufficient bytes are available

### 3.3 Signed Integers

Signed integers SHALL be serialized using two's complement representation in little-endian byte order:

| Type | Width | Min Value | Max Value |
|------|-------|-----------|-----------|
| i8   | 1 byte | -128 | 127 |
| i16  | 2 bytes | -32,768 | 32,767 |
| i32  | 4 bytes | -2,147,483,648 | 2,147,483,647 |
| i64  | 8 bytes | -2^63 | 2^63 - 1 |
| i128 | 16 bytes | -2^127 | 2^127 - 1 |
| i256 | 32 bytes | -2^255 | 2^255 - 1 |

**Examples:**

| Type | Value | Serialized Bytes |
|------|-------|------------------|
| i8 | -1 | `[0xFF]` |
| i8 | -128 | `[0x80]` |
| i8 | 127 | `[0x7F]` |
| i16 | -1 | `[0xFF, 0xFF]` |
| i32 | -1 | `[0xFF, 0xFF, 0xFF, 0xFF]` |

**Requirements:**

- Serializers SHALL use two's complement representation
- Serializers SHALL use little-endian byte order
- The serialized form of a signed integer is identical to casting it to the corresponding unsigned type

---

## 4. ULEB128 Encoding

### 4.1 Overview

ULEB128 (Unsigned Little-Endian Base 128) is a variable-length encoding for unsigned integers. BCS uses ULEB128 to encode:

1. Lengths of variable-length sequences (vectors, strings, bytes, maps)
2. Enum variant indices

### 4.2 Encoding Algorithm

ULEB128 encodes an unsigned integer as a sequence of bytes where:

- Each byte contributes 7 bits of data (bits 0-6)
- Bit 7 (high bit) indicates whether more bytes follow:
  - `1` = more bytes follow
  - `0` = this is the final byte

**Encoding procedure:**

```
while value >= 0x80:
    emit byte: (value & 0x7F) | 0x80
    value = value >> 7
emit byte: value
```

### 4.3 Examples

| Value | Hex | ULEB128 Bytes |
|-------|-----|---------------|
| 0 | 0x00000000 | `[0x00]` |
| 1 | 0x00000001 | `[0x01]` |
| 127 | 0x0000007F | `[0x7F]` |
| 128 | 0x00000080 | `[0x80, 0x01]` |
| 255 | 0x000000FF | `[0xFF, 0x01]` |
| 256 | 0x00000100 | `[0x80, 0x02]` |
| 16383 | 0x00003FFF | `[0xFF, 0x7F]` |
| 16384 | 0x00004000 | `[0x80, 0x80, 0x01]` |
| 2097151 | 0x001FFFFF | `[0xFF, 0xFF, 0x7F]` |
| 2097152 | 0x00200000 | `[0x80, 0x80, 0x80, 0x01]` |
| 268435455 | 0x0FFFFFFF | `[0xFF, 0xFF, 0xFF, 0x7F]` |
| 268435456 | 0x10000000 | `[0x80, 0x80, 0x80, 0x80, 0x01]` |

### 4.4 Requirements

**Serializers:**

- SHALL produce the minimal (canonical) encoding
- SHALL NOT emit leading zero bytes (except for the value 0 itself)

**Deserializers:**

- SHALL reject non-canonical encodings (e.g., `[0x80, 0x00]` for value 0)
- SHALL reject values that exceed 2^32 - 1 (u32 max)
- SHALL reject sequences longer than 5 bytes
- SHALL fail on truncated input

**Invalid ULEB128 Examples:**

| Bytes | Reason |
|-------|--------|
| `[0x80, 0x00]` | Non-canonical: trailing zero byte |
| `[0x80, 0x80, 0x80, 0x80, 0x80, 0x01]` | Overflow: exceeds 5 bytes |
| `[0x80, 0x80, 0x80, 0x80, 0x10]` | Overflow: value exceeds u32 max |
| `[0x80]` | Truncated: continuation bit set but no more bytes |

---

## 5. Composite Types

### 5.1 Byte Arrays

Byte arrays (including strings) SHALL be serialized as:

1. ULEB128-encoded length (number of bytes)
2. Raw bytes

**Requirements:**

- Length SHALL be the byte count, not element count
- Empty arrays SHALL be serialized as `[0x00]` (length 0)

**Examples:**

| Value | Serialized |
|-------|------------|
| `[]` (empty) | `[0x00]` |
| `[0x42]` | `[0x01, 0x42]` |
| `[0x01, 0x02, 0x03]` | `[0x03, 0x01, 0x02, 0x03]` |

### 5.2 Strings

Strings SHALL be serialized as UTF-8 encoded byte arrays:

1. ULEB128-encoded byte length
2. UTF-8 encoded bytes

**Requirements:**

- Serializers SHALL encode strings as valid UTF-8
- Deserializers SHALL validate UTF-8 encoding
- Deserializers SHALL reject invalid UTF-8 sequences
- Length is the byte count, NOT the character count

**Examples:**

| String | UTF-8 Bytes | Serialized |
|--------|-------------|------------|
| `""` | (none) | `[0x00]` |
| `"hello"` | 5 bytes | `[0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F]` |
| `"héllo"` | 6 bytes (é = 2 bytes) | `[0x06, 0x68, 0xC3, 0xA9, 0x6C, 0x6C, 0x6F]` |

### 5.3 Optional Values (Option)

Optional values SHALL be serialized as:

- `None` / `null`: `[0x00]`
- `Some(value)`: `[0x01]` followed by serialized value

**Requirements:**

- Deserializers SHALL reject any tag byte other than `0x00` or `0x01`

**Examples:**

| Value | Type | Serialized |
|-------|------|------------|
| None | Option\<u64\> | `[0x00]` |
| Some(42) | Option\<u64\> | `[0x01, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]` |
| Some(true) | Option\<bool\> | `[0x01, 0x01]` |

### 5.4 Variable-Length Sequences (Vectors)

Variable-length sequences SHALL be serialized as:

1. ULEB128-encoded element count
2. Serialized elements in order

**Requirements:**

- All elements SHALL be of the same type
- Elements SHALL be serialized in index order (0, 1, 2, ...)
- Empty sequences SHALL be serialized as `[0x00]`

**Examples:**

| Value | Type | Serialized |
|-------|------|------------|
| `[]` | Vec\<u8\> | `[0x00]` |
| `[1, 2, 3]` | Vec\<u8\> | `[0x03, 0x01, 0x02, 0x03]` |
| `[1, 2]` | Vec\<u64\> | `[0x02, 0x01, 0x00, ..., 0x02, 0x00, ...]` |

### 5.5 Fixed-Length Arrays

Fixed-length arrays SHALL be serialized as the concatenation of serialized elements WITHOUT a length prefix.

**Requirements:**

- The length MUST be known at deserialization time from the schema
- Elements SHALL be serialized in index order

**Examples:**

| Value | Type | Serialized |
|-------|------|------------|
| `[1, 2, 3]` | [u16; 3] | `[0x01, 0x00, 0x02, 0x00, 0x03, 0x00]` |
| 32 zero bytes | [u8; 32] | `[0x00, 0x00, ..., 0x00]` (32 bytes) |

### 5.6 Structures

Structures SHALL be serialized as the concatenation of serialized fields in declaration order.

**Requirements:**

- Fields SHALL be serialized in the order they are declared in the schema
- No field names or separators SHALL be included
- The schema MUST be known at deserialization time

**Example:**

```
struct Transfer {
    sender: [u8; 32],    // AccountAddress
    recipient: [u8; 32], // AccountAddress
    amount: u64,
}
```

Serialized as: `sender_bytes (32) || recipient_bytes (32) || amount_bytes (8)` = 72 bytes total

### 5.7 Enumerations (Enums)

Enumerations SHALL be serialized as:

1. ULEB128-encoded variant index (0-based)
2. Serialized variant data (if any)

**Requirements:**

- Variant indices SHALL start at 0
- Variant indices SHALL be assigned in declaration order
- Unit variants (no data) SHALL have no additional bytes after the index
- Deserializers SHALL reject unknown variant indices

**Example:**

```
enum Message {
    Quit,           // index 0
    Move { x: i32, y: i32 },  // index 1
    Write(String),  // index 2
}
```

| Value | Serialized |
|-------|------------|
| Quit | `[0x00]` |
| Move { x: 1, y: 2 } | `[0x01, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00]` |
| Write("hi") | `[0x02, 0x02, 0x68, 0x69]` |

### 5.8 Maps

Maps SHALL be serialized as:

1. ULEB128-encoded entry count
2. Key-value pairs in sorted order

**Requirements:**

- Keys SHALL be sorted by the lexicographic order of their BCS-encoded bytes
- Keys SHALL be unique
- Deserializers SHALL reject maps with duplicate keys
- Deserializers SHALL reject maps with out-of-order keys
- Serializers SHALL sort entries before serialization

**Example:**

```
{
    "c" => 3,
    "a" => 1,
    "b" => 2,
}
```

Serialized in order: `a`, `b`, `c` (sorted by key bytes)

---

## 6. Constraints

### 6.1 Maximum Sequence Length

**MAX_SEQUENCE_LENGTH = 2^31 - 1 = 2,147,483,647**

- Serializers SHALL reject sequences exceeding this length
- Deserializers SHALL reject length values exceeding this limit
- This applies to vectors, byte arrays, strings, and maps

### 6.2 Maximum Container Depth

**MAX_CONTAINER_DEPTH = 500**

- Container depth is the number of nested structs and enums
- Serializers SHALL track depth and reject values exceeding this limit
- Deserializers SHALL track depth and reject data exceeding this limit
- Depth counting rules:
  - Entering a struct: depth += 1
  - Entering an enum: depth += 1
  - Tuples, options, and sequences do NOT increase depth
  - Primitive types have depth 0

**Example depth calculation:**

```
struct Outer {           // depth 1
    inner: Inner,        // depth 2 (Inner is a struct)
    values: Vec<u64>,    // still depth 2 (Vec doesn't add depth)
}
```

---

## 7. Error Handling

### 7.1 Serialization Errors

Serializers SHALL fail with an appropriate error for:

| Condition | Error |
|-----------|-------|
| Sequence length > MAX_SEQUENCE_LENGTH | ExceededMaxLength |
| Container depth > MAX_CONTAINER_DEPTH | ExceededContainerDepth |
| Unsupported type (f32, f64, char) | NotSupported |
| I/O error | IoError |

### 7.2 Deserialization Errors

Deserializers SHALL fail with an appropriate error for:

| Condition | Error |
|-----------|-------|
| Unexpected end of input | UnexpectedEof |
| Invalid boolean value (not 0x00 or 0x01) | InvalidBoolean |
| Invalid option tag (not 0x00 or 0x01) | InvalidOption |
| Non-canonical ULEB128 encoding | NonCanonicalUleb128 |
| ULEB128 value overflow | Uleb128Overflow |
| Invalid UTF-8 in string | InvalidUtf8 |
| Sequence length > MAX_SEQUENCE_LENGTH | ExceededMaxLength |
| Container depth > MAX_CONTAINER_DEPTH | ExceededContainerDepth |
| Map keys not sorted | NonCanonicalMap |
| Duplicate map keys | NonCanonicalMap |
| Unknown enum variant | UnknownVariant |
| Remaining bytes after deserialization | RemainingInput |

---

## 8. Security Considerations

### 8.1 Denial of Service

The MAX_SEQUENCE_LENGTH and MAX_CONTAINER_DEPTH limits protect against:

- Memory exhaustion from oversized allocations
- Stack overflow from deeply nested structures

Implementations SHOULD:

- Validate lengths before allocating memory
- Use iterative rather than recursive deserialization where possible

### 8.2 Canonical Serialization

BCS's canonical serialization property is critical for:

- Cryptographic hashing of data structures
- Signature verification
- Consensus agreement on data representation

Implementations SHALL:

- Reject non-canonical ULEB128 encodings
- Reject non-sorted or duplicate map keys
- Produce identical output for identical input values

### 8.3 Type Safety

BCS is NOT self-describing. Implementations SHOULD:

- Require explicit type information for deserialization
- Use type-safe APIs that prevent type confusion
- Consider using unique prefixes/tags for different message types when hashing

---

## Appendix A: Reference Implementations

- **Rust**: https://github.com/diem/bcs (canonical reference)
- **Python**: (this project)
- **TypeScript**: (this project)
- **Go**: (this project)

## Appendix B: Comparison with Other Formats

| Feature | BCS | Protocol Buffers | MessagePack | CBOR |
|---------|-----|-----------------|-------------|------|
| Canonical | Yes | No | No | Optional |
| Self-describing | No | Partial | Yes | Yes |
| Schema required | Yes | Yes | No | No |
| Varint encoding | ULEB128 | Varint | Variable | Variable |
| Map ordering | Required sorted | Undefined | Undefined | Optional |

## Appendix C: Changelog

### Version 1.0.0 (2026-01-26)

- Initial specification
- Added u256/i256 support (extension from original spec)
