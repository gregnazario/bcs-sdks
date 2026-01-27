# BCS C++ SDK

A header-only C++17 implementation of Binary Canonical Serialization (BCS).

## Features

- **Header-only**: Just include and use, no linking required
- **Modern C++17**: Uses `std::optional`, `std::string_view`, structured bindings
- **Type-safe**: Strong typing with compile-time checks
- **Efficient**: Zero-copy where possible, minimal allocations
- **Complete BCS support**: All primitive types, containers, and constraints

## Installation

### Header-only (recommended)

Copy the `include/bcs` directory to your project or include path:

```bash
cp -r include/bcs /usr/local/include/
```

### CMake FetchContent

```cmake
include(FetchContent)
FetchContent_Declare(
    bcs
    GIT_REPOSITORY https://github.com/bcs-sdks/bcs-sdks
    GIT_TAG main
    SOURCE_SUBDIR sdks/cpp
)
FetchContent_MakeAvailable(bcs)

target_link_libraries(your_target PRIVATE bcs)
```

## Quick Start

```cpp
#include <bcs/bcs.hpp>
#include <iostream>

int main() {
    // Serialize
    bcs::Serializer ser;
    ser.write_u64(12345)
       .write_string("hello")
       .write_bool(true);
    
    std::vector<uint8_t> bytes = ser.to_bytes();
    
    // Deserialize
    bcs::Deserializer des(bytes);
    uint64_t num = des.read_u64();
    std::string str = des.read_string();
    bool flag = des.read_bool();
    des.check_end();  // Ensure all bytes consumed
    
    std::cout << "num: " << num << ", str: " << str << ", flag: " << flag << std::endl;
    return 0;
}
```

## Supported Types

| BCS Type | C++ Type | Serialize | Deserialize |
|----------|----------|-----------|-------------|
| bool | `bool` | `write_bool()` | `read_bool()` |
| u8 | `uint8_t` | `write_u8()` | `read_u8()` |
| u16 | `uint16_t` | `write_u16()` | `read_u16()` |
| u32 | `uint32_t` | `write_u32()` | `read_u32()` |
| u64 | `uint64_t` | `write_u64()` | `read_u64()` |
| u128 | `bcs::u128` | `write_u128()` | `read_u128()` |
| u256 | `bcs::u256` | `write_u256()` | `read_u256()` |
| i8 | `int8_t` | `write_i8()` | `read_i8()` |
| i16 | `int16_t` | `write_i16()` | `read_i16()` |
| i32 | `int32_t` | `write_i32()` | `read_i32()` |
| i64 | `int64_t` | `write_i64()` | `read_i64()` |
| i128 | `bcs::i128` | `write_i128()` | `read_i128()` |
| i256 | `bcs::i256` | `write_i256()` | `read_i256()` |
| string | `std::string` | `write_string()` | `read_string()` |
| bytes | `std::vector<uint8_t>` | `write_bytes()` | `read_bytes()` |
| option | `std::optional<T>` | `write_option()` | `read_option()` |
| vector | `std::vector<T>` | `write_vector()` | `read_vector()` |
| map | `std::map<K, V>` | `write_map()` | `read_map()` |

## Complex Types

### Options

```cpp
bcs::Serializer ser;
std::optional<uint32_t> some_value = 42;
std::optional<uint32_t> no_value = std::nullopt;

ser.write_option(some_value, [](bcs::Serializer& s, uint32_t v) {
    s.write_u32(v);
});
ser.write_option(no_value, [](bcs::Serializer& s, uint32_t v) {
    s.write_u32(v);
});

// Deserialize
bcs::Deserializer des(ser.to_bytes());
auto opt1 = des.read_option<uint32_t>([](bcs::Deserializer& d) {
    return d.read_u32();
});
auto opt2 = des.read_option<uint32_t>([](bcs::Deserializer& d) {
    return d.read_u32();
});
```

### Vectors

```cpp
bcs::Serializer ser;
std::vector<uint16_t> values{100, 200, 300};

ser.write_vector(values, [](bcs::Serializer& s, uint16_t v) {
    s.write_u16(v);
});

// Deserialize
bcs::Deserializer des(ser.to_bytes());
auto result = des.read_vector<uint16_t>([](bcs::Deserializer& d) {
    return d.read_u16();
});
```

### Maps

```cpp
bcs::Serializer ser;
std::map<std::string, uint64_t> scores{
    {"alice", 100},
    {"bob", 200}
};

ser.write_map(
    scores,
    [](bcs::Serializer& s, const std::string& k) { s.write_string(k); },
    [](bcs::Serializer& s, uint64_t v) { s.write_u64(v); }
);

// Deserialize
bcs::Deserializer des(ser.to_bytes());
auto result = des.read_map<std::string, uint64_t>(
    [](bcs::Deserializer& d) { return d.read_string(); },
    [](bcs::Deserializer& d) { return d.read_u64(); }
);
```

### Structs

```cpp
struct Person {
    std::string name;
    uint32_t age;
    std::optional<std::string> email;
};

void serialize_person(bcs::Serializer& ser, const Person& p) {
    ser.enter_container();
    ser.write_string(p.name);
    ser.write_u32(p.age);
    ser.write_option(p.email, [](bcs::Serializer& s, const std::string& e) {
        s.write_string(e);
    });
    ser.leave_container();
}

Person deserialize_person(bcs::Deserializer& des) {
    des.enter_container();
    Person p;
    p.name = des.read_string();
    p.age = des.read_u32();
    p.email = des.read_option<std::string>([](bcs::Deserializer& d) {
        return d.read_string();
    });
    des.leave_container();
    return p;
}
```

### Enums

```cpp
enum class MessageType : uint32_t {
    Text = 0,
    Image = 1,
    File = 2
};

struct Message {
    MessageType type;
    std::string content;
};

void serialize_message(bcs::Serializer& ser, const Message& m) {
    ser.enter_container();
    ser.write_variant_index(static_cast<uint32_t>(m.type));
    ser.write_string(m.content);
    ser.leave_container();
}
```

## Error Handling

All errors are thrown as `bcs::Error` exceptions:

```cpp
try {
    bcs::Deserializer des(data);
    auto value = des.read_u64();
} catch (const bcs::Error& e) {
    std::cerr << "BCS error: " << e.what() << std::endl;
    
    switch (e.type()) {
        case bcs::ErrorType::UnexpectedEof:
            // Handle EOF
            break;
        case bcs::ErrorType::InvalidBoolean:
            // Handle invalid boolean
            break;
        // ... other cases
    }
}
```

## ULEB128 Utilities

Direct access to ULEB128 encoding/decoding:

```cpp
#include <bcs/uleb128.hpp>

// Encode
std::vector<uint8_t> encoded = bcs::uleb128::encode(300);

// Decode
auto [value, bytes_consumed] = bcs::uleb128::decode(encoded.data(), encoded.size());

// Get encoded size
size_t size = bcs::uleb128::encoded_size(300);
```

## Development

### Building Tests

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
make lint          # Run clang-tidy
```

### Requirements

- C++17 compatible compiler (clang++, g++, MSVC)
- clang-format (for formatting)
- clang-tidy (for linting)

## License

Apache-2.0
