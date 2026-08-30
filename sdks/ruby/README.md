# BCS Ruby SDK

A Ruby implementation of Binary Canonical Serialization (BCS).

## Features

- **Pure Ruby**: No native extensions required
- **Ruby 2.7+**: Supports modern Ruby versions
- **Comprehensive**: All BCS types including u128/u256
- **Idiomatic**: Block-based API for composite types

## Installation

> **Note:** This gem is not yet published to RubyGems. For now, build and install from source in [sdks/ruby](.).

Add to your Gemfile:

```ruby
gem "bcs"
```

Or install directly:

```bash
gem install bcs
```

## Quick Start

```ruby
require "bcs"

# Serialize
ser = BCS::Serializer.new
ser.write_u64(12345)
ser.write_string("hello")
ser.write_bool(true)
bytes = ser.to_bytes

# Deserialize
des = BCS::Deserializer.new(bytes)
num = des.read_u64
str = des.read_string
flag = des.read_bool
des.check_end  # Ensure all bytes consumed
```

## Supported Types

| BCS Type | Ruby Type | Serialize | Deserialize |
|----------|-----------|-----------|-------------|
| bool | `TrueClass/FalseClass` | `write_bool` | `read_bool` |
| u8 | `Integer` | `write_u8` | `read_u8` |
| u16 | `Integer` | `write_u16` | `read_u16` |
| u32 | `Integer` | `write_u32` | `read_u32` |
| u64 | `Integer` | `write_u64` | `read_u64` |
| u128 | `Integer` | `write_u128` | `read_u128` |
| u256 | `Integer` | `write_u256` | `read_u256` |
| i8 | `Integer` | `write_i8` | `read_i8` |
| i16 | `Integer` | `write_i16` | `read_i16` |
| i32 | `Integer` | `write_i32` | `read_i32` |
| i64 | `Integer` | `write_i64` | `read_i64` |
| i128 | `Integer` | `write_i128` | `read_i128` |
| i256 | `Integer` | `write_i256` | `read_i256` |
| string | `String` | `write_string` | `read_string` |
| bytes | `Array<Integer>` | `write_bytes` | `read_bytes` |
| option | `Object/nil` | `write_option` | `read_option` |
| vector | `Array` | `write_vector` | `read_vector` |
| map | `Hash` | `write_map` | `read_map` |

## Complex Types

### Options

```ruby
ser = BCS::Serializer.new

# Some value
ser.write_option(42) { |s, v| s.write_u32(v) }

# None
ser.write_option(nil) { |s, v| s.write_u32(v) }

# Deserialize
des = BCS::Deserializer.new(ser.to_bytes)
opt1 = des.read_option { |d| d.read_u32 }  # => 42
opt2 = des.read_option { |d| d.read_u32 }  # => nil
```

### Vectors

```ruby
ser = BCS::Serializer.new
ser.write_vector([100, 200, 300]) { |s, v| s.write_u16(v) }

# Deserialize
des = BCS::Deserializer.new(ser.to_bytes)
vec = des.read_vector { |d| d.read_u16 }  # => [100, 200, 300]
```

### Maps

```ruby
ser = BCS::Serializer.new
scores = { "alice" => 100, "bob" => 200 }
ser.write_map(scores) { |s, k| s.write_string(k) }
# Note: value serializer is passed separately

# Deserialize
des = BCS::Deserializer.new(ser.to_bytes)
result = des.read_map do |d, type|
  case type
  when :key then d.read_string
  when :value then d.read_u64
  end
end
```

### Structs

```ruby
class Person
  attr_accessor :name, :age, :email

  def serialize(ser)
    ser.enter_struct
    ser.write_string(name)
    ser.write_u32(age)
    ser.write_option(email) { |s, e| s.write_string(e) }
    ser.leave_struct
  end

  def self.deserialize(des)
    des.enter_struct
    person = new
    person.name = des.read_string
    person.age = des.read_u32
    person.email = des.read_option { |d| d.read_string }
    des.leave_struct
    person
  end
end
```

### Enums

```ruby
class Message
  attr_accessor :type, :content

  def serialize(ser)
    case type
    when :text
      ser.enter_enum(0)
      ser.write_string(content)
      ser.leave_enum
    when :image
      ser.enter_enum(1)
      ser.write_bytes(content[:data])
      ser.write_u32(content[:width])
      ser.write_u32(content[:height])
      ser.leave_enum
    end
  end
end
```

## Error Handling

All errors are raised as `BCS::Error`:

```ruby
begin
  des = BCS::Deserializer.new(data)
  value = des.read_u64
rescue BCS::Error => e
  puts "BCS error: #{e.message}"
  
  case e.type
  when :unexpected_eof
    # Handle EOF
  when :invalid_boolean
    # Handle invalid boolean
  when :invalid_utf8
    # Handle invalid UTF-8
  end
end
```

## ULEB128 Utilities

Direct access to ULEB128 encoding/decoding:

```ruby
require "bcs"

# Encode
encoded = BCS::Uleb128.encode(300)

# Decode
value, bytes_read = BCS::Uleb128.decode(encoded)

# Get encoded size
size = BCS::Uleb128.encoded_size(300)
```

## Hex Utilities

```ruby
# Bytes to hex
hex = BCS.bytes_to_hex([0x01, 0x02, 0xab])  # => "0102ab"

# Hex to bytes
bytes = BCS.hex_to_bytes("0102ab")  # => [1, 2, 171]
```

## Development

### Setup

```bash
bundle install
```

### Testing

```bash
make test
```

### Linting

```bash
make lint     # Check code style
make format   # Auto-fix code style
```

### Building

```bash
make build
```

### Requirements

- Ruby 2.7+
- Bundler 2.0+
- RuboCop (for linting)

## License

Apache-2.0
