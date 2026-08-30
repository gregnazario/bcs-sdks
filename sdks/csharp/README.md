# BCS C# SDK

[![NuGet](https://img.shields.io/nuget/v/Bcs.svg)](https://www.nuget.org/packages/Bcs)
[![.NET](https://img.shields.io/badge/.NET-8.0+-blue.svg)](https://dotnet.microsoft.com/)

Binary Canonical Serialization (BCS) implementation for .NET.

## Installation

> **Note:** This package is not yet published to NuGet. For now, clone this repo, run `make pack` in [sdks/csharp](.), and install the generated `.nupkg` from `nupkg/` (e.g. `dotnet add package Bcs --source ./nupkg`).

```bash
dotnet add package Bcs
```

## Quick Start

### Manual Serialization API

For explicit control over serialization:

```csharp
using Bcs;

// Serialization
var ser = new BcsSerializer();
ser.WriteU8(1);
ser.WriteU64(100);
ser.WriteString("hello");
byte[] bytes = ser.ToArray();

// Deserialization
var des = new BcsDeserializer(bytes);
byte value1 = des.ReadU8();     // 1
ulong value2 = des.ReadU64();   // 100
string value3 = des.ReadString(); // "hello"
des.CheckEnd();  // Verify no remaining bytes
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
| option tag | `WriteOptionTag(hasValue)` | `ReadOptionTag()` |
| vector | `WriteVector(values, serializer)` | `ReadVector(deserializer)` |
| map len | `WriteMapLength(len)` | `ReadMapLength()` |
| ULEB128 | `WriteUleb128(value)` | `ReadUleb128()` |

**C# Type Mappings:**
- `u8`: `byte`
- `u16`: `ushort`
- `u32`: `uint`
- `u64`: `ulong`
- `u128/u256`: `BigInteger`
- `i8`: `sbyte`
- `i16`: `short`
- `i32`: `int`
- `i64`: `long`
- `i128/i256`: `BigInteger`

### Error Handling

All deserialization errors throw `BcsException`:

```csharp
try
{
    var des = new BcsDeserializer(new byte[] { 0x02 });
    des.ReadBool();
}
catch (BcsException ex)
{
    Console.WriteLine(ex.ErrorType);  // InvalidBoolean
    Console.WriteLine(ex.Message);    // "Invalid boolean value: 0x02..."
}
```

Error types include:
- `UnexpectedEof` - Not enough bytes
- `InvalidBoolean` - Boolean value not 0 or 1
- `InvalidOption` - Option tag not 0 or 1
- `InvalidUtf8` - String is not valid UTF-8
- `NonCanonicalUleb128` - ULEB128 has trailing zeros
- `Uleb128Overflow` - ULEB128 exceeds u32 max
- `ExceededMaxLength` - Sequence too long
- `RemainingInput` - Unconsumed bytes after deserialization
- `NonCanonicalMap` - Map keys not sorted or has duplicates
- `ValueOutOfRange` - Integer out of type bounds

### Complex Types

#### Options

```csharp
// Serialize Some(42)
var ser = new BcsSerializer();
ser.WriteOptionTag(true);
ser.WriteU64(42);

// Serialize None
ser.WriteOptionTag(false);

// Using helper method
ser.WriteOption<ulong?>(42, (s, v) => s.WriteU64(v));
ser.WriteOption<ulong?>(null, (s, v) => s.WriteU64(v));

// Deserialize
var des = new BcsDeserializer(bytes);
ulong? value = des.ReadOptionValue(d => d.ReadU64());
```

#### Vectors

```csharp
// Serialize a list of bytes
var ser = new BcsSerializer();
ser.WriteVector(new byte[] { 1, 2, 3 }, (s, v) => s.WriteU8(v));

// Nested vectors
var nested = new List<List<byte>>
{
    new() { 1, 2 },
    new() { 3, 4 }
};
ser.WriteVector(nested, (s, inner) =>
    s.WriteVector(inner, (s2, v) => s2.WriteU8(v)));

// Deserialize
var des = new BcsDeserializer(bytes);
var result = des.ReadVector(d => d.ReadU8());
```

#### Structs

```csharp
// Define a struct (or record)
public record Transfer(byte[] Sender, byte[] Recipient, ulong Amount)
{
    public byte[] Serialize()
    {
        var ser = new BcsSerializer();
        ser.WriteFixedBytes(Sender, 32);
        ser.WriteFixedBytes(Recipient, 32);
        ser.WriteU64(Amount);
        return ser.ToArray();
    }

    public static Transfer Deserialize(byte[] data)
    {
        var des = new BcsDeserializer(data);
        var sender = des.ReadFixedBytes(32);
        var recipient = des.ReadFixedBytes(32);
        var amount = des.ReadU64();
        des.CheckEnd();
        return new Transfer(sender, recipient, amount);
    }
}
```

#### Enums

```csharp
// Serialize variant at index 1 with u64 data
var ser = new BcsSerializer();
ser.WriteVariantIndex(1);
ser.WriteU64(42);

// Deserialize
var des = new BcsDeserializer(bytes);
var index = des.ReadVariantIndex();
switch (index)
{
    case 0:
        // Handle variant 0
        break;
    case 1:
        var value = des.ReadU64();
        // Handle variant 1 with value
        break;
}
```

### ULEB128 Utilities

```csharp
using Bcs;

// Encode
byte[] encoded = Uleb128.Encode(12345);

// Decode
Uleb128.Decode(encoded, out uint value, out int bytesConsumed);

// Get encoded size
int size = Uleb128.EncodedSize(12345);
```

## C#-Idiomatic Features

- Method chaining: `ser.WriteU8(1).WriteU64(100).WriteString("hello")`
- `Span<byte>` and `ReadOnlySpan<byte>` support for zero-copy operations
- `BigInteger` for 128/256-bit integers
- Nullable reference types and value types for options
- Generic methods with delegates for collections
- XML documentation comments

## Development

```bash
# Restore dependencies
make deps

# Run tests
make test

# Format code
make format

# Check formatting
make format-check

# Build
make build

# Pack NuGet package
make pack
```

## License

Apache-2.0
