# BCS C SDK

A C99 implementation of Binary Canonical Serialization (BCS).

## Features

- **Pure C99**: No external dependencies
- **Error Handling**: Error codes with descriptive messages
- **Static or Dynamic Buffers**: Use your own buffer or let BCS allocate
- **Full BCS Support**: All primitive and composite types
- **UTF-8 Validation**: Strict string validation

## Building

```bash
make build    # Build static library
make test     # Run tests
make install  # Install headers and library
```

## Quick Start

```c
#include <bcs/bcs.h>
#include <stdio.h>

int main(void) {
    // Serialize
    uint8_t buffer[256];
    bcs_serializer_t ser;
    bcs_serializer_init(&ser, buffer, sizeof(buffer));

    bcs_write_u64(&ser, 12345);
    bcs_write_string(&ser, "hello");
    bcs_write_bool(&ser, true);

    // Deserialize
    bcs_deserializer_t des;
    bcs_deserializer_init(&des, buffer, bcs_serializer_size(&ser));

    uint64_t num;
    bcs_read_u64(&des, &num);

    char str[32];
    size_t str_len;
    bcs_read_string(&des, str, sizeof(str), &str_len);

    bool flag;
    bcs_read_bool(&des, &flag);

    bcs_check_end(&des);  // Ensure all bytes consumed

    printf("num=%llu, str=%s, flag=%d\n", num, str, flag);
    return 0;
}
```

## API Reference

### Serializer

```c
// Initialize with user-provided buffer
bcs_error_t bcs_serializer_init(bcs_serializer_t* ser, uint8_t* buffer, size_t capacity);

// Initialize with dynamic allocation (auto-grows)
bcs_error_t bcs_serializer_init_dynamic(bcs_serializer_t* ser, size_t initial_capacity);

// Free resources (only needed for dynamic allocation)
void bcs_serializer_free(bcs_serializer_t* ser);

// Get output
const uint8_t* bcs_serializer_bytes(const bcs_serializer_t* ser);
size_t bcs_serializer_size(const bcs_serializer_t* ser);
```

### Deserializer

```c
// Initialize
bcs_error_t bcs_deserializer_init(bcs_deserializer_t* des, const uint8_t* data, size_t size);

// Check all input consumed
bcs_error_t bcs_check_end(const bcs_deserializer_t* des);

// Get remaining bytes
size_t bcs_remaining(const bcs_deserializer_t* des);
```

### Primitive Types

| Type | Serialize | Deserialize |
|------|-----------|-------------|
| bool | `bcs_write_bool` | `bcs_read_bool` |
| u8 | `bcs_write_u8` | `bcs_read_u8` |
| u16 | `bcs_write_u16` | `bcs_read_u16` |
| u32 | `bcs_write_u32` | `bcs_read_u32` |
| u64 | `bcs_write_u64` | `bcs_read_u64` |
| u128 | `bcs_write_u128` | `bcs_read_u128` |
| u256 | `bcs_write_u256` | `bcs_read_u256` |
| i8 | `bcs_write_i8` | `bcs_read_i8` |
| i16 | `bcs_write_i16` | `bcs_read_i16` |
| i32 | `bcs_write_i32` | `bcs_read_i32` |
| i64 | `bcs_write_i64` | `bcs_read_i64` |

Note: u128/u256 and i128/i256 use `uint8_t[16]` and `uint8_t[32]` arrays in little-endian order.

### Strings and Bytes

```c
// Write/read length-prefixed bytes
bcs_error_t bcs_write_bytes(bcs_serializer_t* ser, const uint8_t* data, size_t len);
bcs_error_t bcs_read_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t buffer_size, size_t* out_len);

// Write/read length-prefixed UTF-8 string
bcs_error_t bcs_write_string(bcs_serializer_t* ser, const char* str);
bcs_error_t bcs_read_string(bcs_deserializer_t* des, char* buffer, size_t buffer_size, size_t* out_len);

// Write/read fixed-length bytes (no length prefix)
bcs_error_t bcs_write_fixed_bytes(bcs_serializer_t* ser, const uint8_t* data, size_t len);
bcs_error_t bcs_read_fixed_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t len);
```

### Options

```c
// Serialize
bcs_write_option_none(&ser);  // None
bcs_write_option_some(&ser);  // Some (then write the value)
bcs_write_u32(&ser, 42);

// Deserialize
bool is_some;
bcs_read_option_tag(&des, &is_some);
if (is_some) {
    uint32_t value;
    bcs_read_u32(&des, &value);
}
```

### Vectors

```c
// Serialize
bcs_write_vector_len(&ser, 3);
bcs_write_u8(&ser, 1);
bcs_write_u8(&ser, 2);
bcs_write_u8(&ser, 3);

// Deserialize
size_t len;
bcs_read_vector_len(&des, &len);
for (size_t i = 0; i < len; i++) {
    uint8_t val;
    bcs_read_u8(&des, &val);
}
```

### Structs

```c
typedef struct {
    uint8_t sender[32];
    uint8_t recipient[32];
    uint64_t amount;
} transfer_t;

bcs_error_t serialize_transfer(const transfer_t* t, bcs_serializer_t* ser) {
    bcs_error_t err;
    
    err = bcs_enter_struct(ser);
    if (err != BCS_OK) return err;
    
    err = bcs_write_fixed_bytes(ser, t->sender, 32);
    if (err != BCS_OK) return err;
    
    err = bcs_write_fixed_bytes(ser, t->recipient, 32);
    if (err != BCS_OK) return err;
    
    err = bcs_write_u64(ser, t->amount);
    if (err != BCS_OK) return err;
    
    return bcs_leave_struct(ser);
}

bcs_error_t deserialize_transfer(bcs_deserializer_t* des, transfer_t* t) {
    bcs_error_t err;
    
    err = bcs_des_enter_struct(des);
    if (err != BCS_OK) return err;
    
    err = bcs_read_fixed_bytes(des, t->sender, 32);
    if (err != BCS_OK) return err;
    
    err = bcs_read_fixed_bytes(des, t->recipient, 32);
    if (err != BCS_OK) return err;
    
    err = bcs_read_u64(des, &t->amount);
    if (err != BCS_OK) return err;
    
    return bcs_des_leave_struct(des);
}
```

### Enums

```c
// Serialize enum variant
bcs_write_variant_index(&ser, 1);  // Variant index
bcs_write_u64(&ser, 42);           // Variant data
bcs_leave_enum(&ser);

// Deserialize
uint32_t variant;
bcs_read_variant_index(&des, &variant);
switch (variant) {
    case 0:
        // Handle variant 0
        break;
    case 1:
        uint64_t value;
        bcs_read_u64(&des, &value);
        // Handle variant 1
        break;
}
bcs_des_leave_enum(&des);
```

## Error Handling

All functions return `bcs_error_t`. Check for `BCS_OK`:

```c
bcs_error_t err = bcs_write_u64(&ser, value);
if (err != BCS_OK) {
    fprintf(stderr, "BCS error: %s\n", bcs_error_message(err));
    return err;
}
```

Error codes:
- `BCS_OK` - Success
- `BCS_ERR_UNEXPECTED_EOF` - Not enough data
- `BCS_ERR_INVALID_BOOLEAN` - Boolean not 0 or 1
- `BCS_ERR_NON_CANONICAL_ULEB128` - Non-canonical ULEB128
- `BCS_ERR_ULEB128_OVERFLOW` - ULEB128 overflow
- `BCS_ERR_EXCEEDED_MAX_LENGTH` - Sequence too long
- `BCS_ERR_EXCEEDED_CONTAINER_DEPTH` - Nesting too deep
- `BCS_ERR_INVALID_UTF8` - Invalid UTF-8
- `BCS_ERR_REMAINING_INPUT` - Extra bytes after deserialization
- `BCS_ERR_BUFFER_TOO_SMALL` - Output buffer too small
- `BCS_ERR_NULL_POINTER` - Null argument

## ULEB128 Utilities

```c
// Direct ULEB128 encoding
uint8_t buf[5];
size_t len = bcs_uleb128_encode(300, buf, sizeof(buf));

// Direct ULEB128 decoding
uint32_t value;
bcs_error_t err;
size_t bytes_read = bcs_uleb128_decode(data, size, &value, &err);

// Get encoded size
size_t size = bcs_uleb128_encoded_size(300);  // Returns 2
```

## Hex Utilities

```c
// Bytes to hex
uint8_t bytes[] = {0x01, 0x02, 0xab};
char hex[16];
bcs_bytes_to_hex(bytes, 3, hex, sizeof(hex));  // "0102ab"

// Hex to bytes
uint8_t out[16];
size_t len = bcs_hex_to_bytes("0102ab", out, sizeof(out));  // len = 3
```

## Requirements

- C99 compiler (GCC, Clang, MSVC)
- No external dependencies

## Development

```bash
make build        # Build library
make test         # Run tests
make debug        # Build with debug symbols
make sanitize     # Build and run with ASan/UBSan
make lint         # Run clang-tidy
make format       # Format code with clang-format
make clean        # Remove build artifacts
```

## License

Apache-2.0
