# BCS Java SDK

[![Maven Central](https://img.shields.io/maven-central/v/com.bcs/bcs.svg)](https://search.maven.org/artifact/com.bcs/bcs)
[![Java](https://img.shields.io/badge/Java-17+-blue.svg)](https://openjdk.java.net/)

Binary Canonical Serialization (BCS) implementation for Java.

## Installation

### Maven

```xml
<dependency>
    <groupId>com.bcs</groupId>
    <artifactId>bcs</artifactId>
    <version>1.0.0</version>
</dependency>
```

### Gradle

```groovy
implementation 'com.bcs:bcs:1.0.0'
```

## Quick Start

### Manual Serialization API

For explicit control over serialization:

```java
import com.bcs.BcsSerializer;
import com.bcs.BcsDeserializer;

// Serialization
BcsSerializer ser = new BcsSerializer();
ser.writeU8((short) 1);
ser.writeU64(100L);
ser.writeString("hello");
byte[] bytes = ser.toBytes();

// Deserialization
BcsDeserializer des = new BcsDeserializer(bytes);
short value1 = des.readU8();    // 1
long value2 = des.readU64();    // 100
String value3 = des.readString(); // "hello"
des.checkEnd();  // Verify no remaining bytes
```

### Supported Types

| Type | Serialize | Deserialize |
|------|-----------|-------------|
| bool | `writeBool(value)` | `readBool()` |
| u8 | `writeU8(value)` | `readU8()` |
| u16 | `writeU16(value)` | `readU16()` |
| u32 | `writeU32(value)` | `readU32()` |
| u64 | `writeU64(value)` | `readU64()` |
| u128 | `writeU128(value)` | `readU128()` |
| u256 | `writeU256(value)` | `readU256()` |
| i8 | `writeI8(value)` | `readI8()` |
| i16 | `writeI16(value)` | `readI16()` |
| i32 | `writeI32(value)` | `readI32()` |
| i64 | `writeI64(value)` | `readI64()` |
| i128 | `writeI128(value)` | `readI128()` |
| i256 | `writeI256(value)` | `readI256()` |
| bytes | `writeBytes(value)` | `readBytes()` |
| string | `writeString(value)` | `readString()` |
| fixed bytes | `writeFixedBytes(value, len)` | `readFixedBytes(len)` |
| option | `writeOption(value, serFn)` | `readOption(desFn)` |
| vector | `writeVector(values, serFn)` | `readVector(desFn)` |
| map | `writeMap(entries, keyFn, valFn)` | `readMap(keyFn, valFn)` |
| ULEB128 | `writeUleb128(value)` | `readUleb128()` |

**Java Type Mappings:**
- `u8`: `short` (0-255)
- `u16`: `int` (0-65535)
- `u32`: `long` (0 to 2^32-1)
- `u64`: `long` (treat as unsigned)
- `u128/u256`: `BigInteger`
- `i8`: `byte`
- `i16`: `short`
- `i32`: `int`
- `i64`: `long`
- `i128/i256`: `BigInteger`

### Error Handling

All deserialization errors throw `BcsError`:

```java
import com.bcs.BcsError;

try {
    BcsDeserializer des = new BcsDeserializer(new byte[]{0x02});
    des.readBool();
} catch (BcsError e) {
    System.out.println(e.getType());    // INVALID_BOOLEAN
    System.out.println(e.getMessage()); // "Invalid boolean value: 0x02..."
}
```

Error types include:
- `UNEXPECTED_EOF` - Not enough bytes
- `INVALID_BOOLEAN` - Boolean value not 0 or 1
- `INVALID_OPTION` - Option tag not 0 or 1
- `INVALID_UTF8` - String is not valid UTF-8
- `NON_CANONICAL_ULEB128` - ULEB128 has trailing zeros
- `ULEB128_OVERFLOW` - ULEB128 exceeds u32 max
- `EXCEEDED_MAX_LENGTH` - Sequence too long
- `REMAINING_INPUT` - Unconsumed bytes after deserialization
- `NON_CANONICAL_MAP` - Map keys not sorted or has duplicates
- `VALUE_OUT_OF_RANGE` - Integer out of type bounds

### Complex Types

#### Options

```java
// Serialize Some(42L)
BcsSerializer ser = new BcsSerializer();
ser.writeOption(42L, (s, v) -> s.writeU64(v));

// Serialize None
ser.writeOption(null, (s, v) -> s.writeU64((Long) v));

// Deserialize
BcsDeserializer des = new BcsDeserializer(bytes);
Long value = des.readOption(BcsDeserializer::readU64); // Long or null
```

#### Vectors

```java
// Serialize a list of u8
BcsSerializer ser = new BcsSerializer();
List<Short> values = List.of((short) 1, (short) 2, (short) 3);
ser.writeVector(values, (s, v) -> s.writeU8(v));

// Nested vectors
List<List<Short>> nested = List.of(
    List.of((short) 1, (short) 2),
    List.of((short) 3, (short) 4)
);
ser.writeVector(nested, (s, inner) ->
    s.writeVector(inner, (s2, v) -> s2.writeU8(v))
);

// Deserialize
BcsDeserializer des = new BcsDeserializer(bytes);
List<Short> result = des.readVector(BcsDeserializer::readU8);
```

#### Structs

```java
// Define a struct class
public class Transfer {
    private final byte[] sender;
    private final byte[] recipient;
    private final long amount;

    // ... constructor, getters ...

    public byte[] serialize() {
        BcsSerializer ser = new BcsSerializer();
        ser.writeFixedBytes(sender, 32);
        ser.writeFixedBytes(recipient, 32);
        ser.writeU64(amount);
        return ser.toBytes();
    }

    public static Transfer deserialize(byte[] data) {
        BcsDeserializer des = new BcsDeserializer(data);
        byte[] sender = des.readFixedBytes(32);
        byte[] recipient = des.readFixedBytes(32);
        long amount = des.readU64();
        des.checkEnd();
        return new Transfer(sender, recipient, amount);
    }
}
```

#### Enums

```java
// Serialize variant at index 1 with u64 data
BcsSerializer ser = new BcsSerializer();
ser.writeVariantIndex(1);
ser.writeU64(42L);

// Deserialize
BcsDeserializer des = new BcsDeserializer(bytes);
int index = des.readVariantIndex();
switch (index) {
    case 0:
        // Handle variant 0
        break;
    case 1:
        long value = des.readU64();
        // Handle variant 1 with value
        break;
}
```

### ULEB128 Utilities

```java
import com.bcs.Uleb128;

// Encode
byte[] encoded = Uleb128.encode(12345);

// Decode
Uleb128.DecodeResult result = Uleb128.decode(encoded, 0);
long value = result.getValue();          // 12345
int bytesRead = result.getBytesConsumed(); // 2

// Get encoded size
int size = Uleb128.encodedSize(12345);  // 2
```

## Development

```bash
# Install dependencies and format tool
make deps

# Run tests
make test

# Format code (uses google-java-format)
make format

# Check formatting
make format-check

# Lint (uses checkstyle)
make lint

# Build
make build
```

## License

Apache-2.0
