# BCS Python SDK

Binary Canonical Serialization (BCS) implementation for Python.

## Installation

```bash
pip install bcs
```

## Quick Start

### Manual Serialization API

For explicit control over serialization:

```python
from bcs import BcsSerializer, BcsDeserializer

# Serialization
s = BcsSerializer()
s.write_u8(1)
s.write_u64(100)
s.write_string("hello")
data = s.to_bytes()

# Deserialization
d = BcsDeserializer(data)
value1 = d.read_u8()      # 1
value2 = d.read_u64()     # 100
value3 = d.read_string()  # "hello"
d.check_end()  # Verify no remaining bytes
```

### Supported Types

| Type | Serialize | Deserialize |
|------|-----------|-------------|
| bool | `write_bool(value)` | `read_bool()` |
| u8 | `write_u8(value)` | `read_u8()` |
| u16 | `write_u16(value)` | `read_u16()` |
| u32 | `write_u32(value)` | `read_u32()` |
| u64 | `write_u64(value)` | `read_u64()` |
| u128 | `write_u128(value)` | `read_u128()` |
| u256 | `write_u256(value)` | `read_u256()` |
| i8 | `write_i8(value)` | `read_i8()` |
| i16 | `write_i16(value)` | `read_i16()` |
| i32 | `write_i32(value)` | `read_i32()` |
| i64 | `write_i64(value)` | `read_i64()` |
| i128 | `write_i128(value)` | `read_i128()` |
| i256 | `write_i256(value)` | `read_i256()` |
| bytes | `write_bytes(value)` | `read_bytes()` |
| string | `write_string(value)` | `read_string()` |
| fixed bytes | `write_fixed_bytes(value, length)` | `read_fixed_bytes(length)` |
| option | `write_option(value, serializer)` | `read_option(deserializer)` |
| vector | `write_vector(values, serializer)` | `read_vector(deserializer)` |
| map | `write_map(items, key_ser, val_ser)` | `read_map(key_des, val_des)` |
| ULEB128 | `write_uleb128(value)` | `read_uleb128()` |

### Complex Types

#### Options

```python
# Serialize Some(42)
s = BcsSerializer()
s.write_option_u64(42)

# Serialize None
s.write_option_u64(None)

# Custom type in Option
s.write_option(my_value, lambda ser, v: ser.write_string(v))
```

#### Vectors

```python
# Vector of u64
s = BcsSerializer()
s.write_vector_u64([1, 2, 3])

# Nested vectors
s.write_vector(
    [[1, 2], [3, 4]],
    lambda ser, v: ser.write_vector_u8(v)
)
```

#### Structs

```python
# Manual struct serialization
s = BcsSerializer()
s.enter_struct("MyStruct")
s.write_u64(100)
s.write_string("hello")
s.leave_struct()
data = s.to_bytes()

# Deserialization
d = BcsDeserializer(data)
d.enter_struct("MyStruct")
field1 = d.read_u64()
field2 = d.read_string()
d.leave_struct()
d.check_end()
```

#### Enums

```python
# Serialize variant at index 1 with u64 data
s = BcsSerializer()
s.write_variant_index(1)
s.write_u64(42)
s.leave_enum()

# Deserialize
d = BcsDeserializer(data)
index = d.read_variant_index()
if index == 0:
    # Handle variant 0
    pass
elif index == 1:
    value = d.read_u64()
d.leave_enum()
```

### Error Handling

```python
from bcs import (
    BcsError,
    UnexpectedEof,
    InvalidBoolean,
    InvalidOption,
    InvalidUtf8,
    NonCanonicalUleb128,
    Uleb128Overflow,
    ExceededMaxLength,
    ExceededContainerDepth,
    RemainingInput,
    NonCanonicalMap,
)

try:
    d = BcsDeserializer(data)
    value = d.read_bool()
except InvalidBoolean as e:
    print(f"Invalid boolean: {e}")
except UnexpectedEof as e:
    print(f"Unexpected end of input: {e}")
```

### ULEB128 Utilities

```python
from bcs import uleb128

# Encode
encoded = uleb128.encode(12345)  # bytes

# Decode
value, offset = uleb128.decode(data, start_offset)

# Get encoded size
size = uleb128.encoded_size(12345)  # 2 bytes
```

## Development

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
make test

# Format code
make format

# Lint
make lint
```

## License

Apache-2.0
