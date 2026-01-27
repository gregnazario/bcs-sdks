# BCS Go SDK

[![Go Reference](https://pkg.go.dev/badge/github.com/bcs-sdks/bcs-go.svg)](https://pkg.go.dev/github.com/bcs-sdks/bcs-go)
[![Go](https://img.shields.io/badge/Go-1.21+-blue.svg)](https://golang.org/)

Binary Canonical Serialization (BCS) implementation for Go.

## Installation

```bash
go get github.com/bcs-sdks/bcs-go/bcs
```

## Quick Start

### Manual Serialization API

For explicit control over serialization:

```go
import "github.com/bcs-sdks/bcs-go/bcs"

// Serialization
ser := bcs.NewSerializer()
ser.WriteU8(1)
ser.WriteU64(100)
ser.WriteString("hello")
bytes := ser.Bytes()

// Deserialization
des := bcs.NewDeserializer(bytes)
value1, _ := des.ReadU8()    // 1
value2, _ := des.ReadU64()   // 100
value3, _ := des.ReadString() // "hello"
des.CheckEnd()  // Verify no remaining bytes
```

### Supported Types

| Type | Serialize | Deserialize |
|------|-----------|-------------|
| bool | `WriteBool(value)` | `ReadBool()` |
| u8 | `WriteU8(value)` | `ReadU8()` |
| u16 | `WriteU16(value)` | `ReadU16()` |
| u32 | `WriteU32(value)` | `ReadU32()` |
| u64 | `WriteU64(value)` | `ReadU64()` |
| u128 | `WriteU128(value)` | `ReadU128()` |
| u256 | `WriteU256(value)` | `ReadU256()` |
| i8 | `WriteI8(value)` | `ReadI8()` |
| i16 | `WriteI16(value)` | `ReadI16()` |
| i32 | `WriteI32(value)` | `ReadI32()` |
| i64 | `WriteI64(value)` | `ReadI64()` |
| i128 | `WriteI128(value)` | `ReadI128()` |
| i256 | `WriteI256(value)` | `ReadI256()` |
| bytes | `WriteBytes(value)` | `ReadBytes()` |
| string | `WriteString(value)` | `ReadString()` |
| fixed bytes | `WriteFixedBytes(value, len)` | `ReadFixedBytes(len)` |
| option tag | `WriteOptionBool(hasValue)` | `ReadOptionTag()` |
| vector len | `WriteVectorLen(len)` | `ReadVectorLen()` |
| map len | `WriteMapLen(len)` | `ReadMapLen()` |
| ULEB128 | `WriteULEB128(value)` | `ReadULEB128()` |

**Go Type Mappings:**
- `u8`: `uint8`
- `u16`: `uint16`
- `u32`: `uint32`
- `u64`: `uint64`
- `u128/u256`: `*big.Int`
- `i8`: `int8`
- `i16`: `int16`
- `i32`: `int32`
- `i64`: `int64`
- `i128/i256`: `*big.Int`

### Error Handling

All deserialization methods return an error:

```go
import "github.com/bcs-sdks/bcs-go/bcs"

des := bcs.NewDeserializer(data)
value, err := des.ReadBool()
if err != nil {
    var bcsErr *bcs.Error
    if errors.As(err, &bcsErr) {
        fmt.Println(bcsErr.Type)    // bcs.ErrInvalidBoolean
        fmt.Println(bcsErr.Message) // "invalid boolean value: 0x02..."
    }
}
```

Error types include:
- `ErrUnexpectedEOF` - Not enough bytes
- `ErrInvalidBoolean` - Boolean value not 0 or 1
- `ErrInvalidOption` - Option tag not 0 or 1
- `ErrInvalidUTF8` - String is not valid UTF-8
- `ErrNonCanonicalULEB128` - ULEB128 has trailing zeros
- `ErrULEB128Overflow` - ULEB128 exceeds u32 max
- `ErrExceededMaxLength` - Sequence too long
- `ErrRemainingInput` - Unconsumed bytes after deserialization
- `ErrNonCanonicalMap` - Map keys not sorted or has duplicates
- `ErrValueOutOfRange` - Integer out of type bounds

### Complex Types

#### Options

```go
// Serialize Some(42)
ser := bcs.NewSerializer()
ser.WriteOptionBool(true)
ser.WriteU64(42)

// Serialize None
ser.WriteOptionBool(false)

// Deserialize
des := bcs.NewDeserializer(bytes)
hasValue, _ := des.ReadOptionTag()
if hasValue {
    value, _ := des.ReadU64()
    // Use value
}
```

#### Vectors

```go
// Serialize a list of u8
ser := bcs.NewSerializer()
values := []uint8{1, 2, 3}
ser.WriteVectorLen(len(values))
for _, v := range values {
    ser.WriteU8(v)
}

// Nested vectors
nested := [][]uint8{{1, 2}, {3, 4}}
ser.WriteVectorLen(len(nested))
for _, inner := range nested {
    ser.WriteVectorLen(len(inner))
    for _, v := range inner {
        ser.WriteU8(v)
    }
}

// Deserialize
des := bcs.NewDeserializer(bytes)
length, _ := des.ReadVectorLen()
result := make([]uint8, length)
for i := range result {
    result[i], _ = des.ReadU8()
}
```

#### Structs

```go
// Define a struct
type Transfer struct {
    Sender    [32]byte
    Recipient [32]byte
    Amount    uint64
}

// Serialize
func (t *Transfer) Serialize() []byte {
    ser := bcs.NewSerializer()
    ser.WriteFixedBytes(t.Sender[:], 32)
    ser.WriteFixedBytes(t.Recipient[:], 32)
    ser.WriteU64(t.Amount)
    return ser.Bytes()
}

// Deserialize
func DeserializeTransfer(data []byte) (*Transfer, error) {
    des := bcs.NewDeserializer(data)
    t := &Transfer{}
    
    sender, err := des.ReadFixedBytes(32)
    if err != nil {
        return nil, err
    }
    copy(t.Sender[:], sender)
    
    recipient, err := des.ReadFixedBytes(32)
    if err != nil {
        return nil, err
    }
    copy(t.Recipient[:], recipient)
    
    t.Amount, err = des.ReadU64()
    if err != nil {
        return nil, err
    }
    
    if err := des.CheckEnd(); err != nil {
        return nil, err
    }
    return t, nil
}
```

#### Enums

```go
// Serialize variant at index 1 with u64 data
ser := bcs.NewSerializer()
ser.WriteVariantIndex(1)
ser.WriteU64(42)

// Deserialize
des := bcs.NewDeserializer(bytes)
index, _ := des.ReadVariantIndex()
switch index {
case 0:
    // Handle variant 0
case 1:
    value, _ := des.ReadU64()
    // Handle variant 1 with value
}
```

### ULEB128 Utilities

```go
import "github.com/bcs-sdks/bcs-go/bcs"

// Encode
encoded := bcs.EncodeULEB128(12345)

// Decode
value, bytesRead, err := bcs.DecodeULEB128(encoded)

// Get encoded size
size := bcs.EncodedSizeULEB128(12345)
```

## Go-Idiomatic Features

- Method chaining: `ser.WriteU8(1).WriteU64(100).WriteString("hello")`
- Error handling with `errors.Is` and `errors.As` support
- Zero allocation for fixed-size types
- `*big.Int` for 128/256-bit integers
- Clean separation of serializer/deserializer

## Development

```bash
# Install dependencies
make deps

# Run tests
make test

# Format code
make format

# Check formatting
make format-check

# Lint
make lint

# Build (verify compilation)
make build
```

## License

Apache-2.0
