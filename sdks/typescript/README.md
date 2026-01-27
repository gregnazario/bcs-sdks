# BCS TypeScript SDK

[![npm version](https://img.shields.io/npm/v/@bcs-sdks/bcs.svg)](https://www.npmjs.com/package/@bcs-sdks/bcs)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-blue.svg)](https://www.typescriptlang.org/)

Binary Canonical Serialization (BCS) implementation for TypeScript/JavaScript.

## Installation

```bash
npm install @bcs-sdks/bcs
```

## Quick Start

### Manual Serialization API

For explicit control over serialization:

```typescript
import { BcsSerializer, BcsDeserializer } from "@bcs-sdks/bcs";

// Serialization
const ser = new BcsSerializer();
ser.writeU8(1);
ser.writeU64(100n);
ser.writeString("hello");
const bytes = ser.toBytes();

// Deserialization
const des = new BcsDeserializer(bytes);
const value1 = des.readU8();    // 1
const value2 = des.readU64();   // 100n
const value3 = des.readString(); // "hello"
des.checkEnd();  // Verify no remaining bytes
```

### Convenience Functions

```typescript
import { serialize, deserialize, serializeU64, deserializeU64 } from "@bcs-sdks/bcs";

// Using serialize/deserialize helpers
const bytes = serialize((ser) => {
  ser.writeU8(1);
  ser.writeU64(100n);
});

const [a, b] = deserialize(bytes, (des) => {
  return [des.readU8(), des.readU64()];
});

// Single-value convenience functions
const u64Bytes = serializeU64(12345n);
const value = deserializeU64(u64Bytes);
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

**Note:** 64-bit and larger integers use JavaScript's native `bigint` type.

### Error Handling

All deserialization errors throw `BcsError`:

```typescript
import { BcsError, BcsDeserializer, hexToBytes } from "@bcs-sdks/bcs";

try {
  const des = new BcsDeserializer(hexToBytes("02"));
  des.readBool();
} catch (e) {
  if (e instanceof BcsError) {
    console.log(e.type);    // "INVALID_BOOLEAN"
    console.log(e.message); // "Invalid boolean value: 0x02..."
  }
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

```typescript
// Serialize Some(42)
const ser = new BcsSerializer();
ser.writeOption(42, (s, v) => s.writeU64(v));

// Serialize None
ser.writeOption(null, (s, v: bigint) => s.writeU64(v));

// Deserialize
const des = new BcsDeserializer(bytes);
const value = des.readOption((d) => d.readU64()); // bigint | null
```

#### Vectors

```typescript
// Serialize a list of u8
const ser = new BcsSerializer();
ser.writeVector([1, 2, 3], (s, v) => s.writeU8(v));

// Nested vectors
ser.writeVector([[1, 2], [3, 4]], (s, inner) => {
  s.writeVector(inner, (s2, v) => s2.writeU8(v));
});

// Deserialize
const des = new BcsDeserializer(bytes);
const values = des.readVector((d) => d.readU8());
```

#### Structs

```typescript
// Define a struct type
interface Transfer {
  sender: Uint8Array;    // 32 bytes
  recipient: Uint8Array; // 32 bytes
  amount: bigint;        // u64
}

// Serialize
function serializeTransfer(t: Transfer): Uint8Array {
  const ser = new BcsSerializer();
  ser.writeFixedBytes(t.sender, 32);
  ser.writeFixedBytes(t.recipient, 32);
  ser.writeU64(t.amount);
  return ser.toBytes();
}

// Deserialize
function deserializeTransfer(data: Uint8Array): Transfer {
  const des = new BcsDeserializer(data);
  const sender = des.readFixedBytes(32);
  const recipient = des.readFixedBytes(32);
  const amount = des.readU64();
  des.checkEnd();
  return { sender, recipient, amount };
}
```

#### Enums

```typescript
// Serialize variant at index 1 with u64 data
const ser = new BcsSerializer();
ser.writeVariantIndex(1);
ser.writeU64(42n);

// Deserialize
const des = new BcsDeserializer(bytes);
const index = des.readVariantIndex();
switch (index) {
  case 0:
    // Handle variant 0
    break;
  case 1:
    const value = des.readU64();
    // Handle variant 1 with value
    break;
}
```

### ULEB128 Utilities

```typescript
import { uleb128 } from "@bcs-sdks/bcs";

// Encode
const encoded = uleb128.encode(12345);  // Uint8Array([0xB9, 0x60])

// Decode
const [value, bytesRead] = uleb128.decode(encoded);  // [12345, 2]

// Get encoded size
const size = uleb128.encodedSize(12345);  // 2
```

### Hex Utilities

```typescript
import { hexToBytes, bytesToHex } from "@bcs-sdks/bcs";

const bytes = hexToBytes("0102030405");
const hex = bytesToHex(bytes);  // "0102030405"

// Also works with 0x prefix
const bytes2 = hexToBytes("0x0102030405");
```

## Development

```bash
# Install dependencies
npm ci

# Run tests
npm test

# Format code
npm run format

# Lint
npm run lint

# Type check
npm run typecheck

# Build
npm run build
```

## License

Apache-2.0
