# BCS Elixir SDK

[![Hex.pm](https://img.shields.io/hexpm/v/bcs.svg)](https://hex.pm/packages/bcs)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/bcs)

Binary Canonical Serialization (BCS) implementation for Elixir.

## Installation

> **Note:** This package is not yet published to Hex. For now, clone this repo and depend on it by path: `{:bcs, path: "../bcs-sdks/sdks/elixir"}`.

Add `bcs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bcs, "~> 1.0"}
  ]
end
```

## Quick Start

### Manual Serialization API

For explicit control over serialization:

```elixir
alias Bcs.{Serializer, Deserializer}

# Serialization - pipe through write functions
data =
  Serializer.new()
  |> Serializer.write_u8(1)
  |> Serializer.write_u64(100)
  |> Serializer.write_string("hello")
  |> Serializer.to_bytes()

# Deserialization - pattern match the rest
{value1, rest} = Deserializer.read_u8!(data)
{value2, rest} = Deserializer.read_u64!(rest)
{value3, rest} = Deserializer.read_string!(rest)
Deserializer.check_end!(rest)  # Verify no remaining bytes

IO.inspect({value1, value2, value3})  # {1, 100, "hello"}
```

### Supported Types

| Type | Serialize | Deserialize |
|------|-----------|-------------|
| bool | `write_bool(data, value)` | `read_bool(data)` |
| u8 | `write_u8(data, value)` | `read_u8(data)` |
| u16 | `write_u16(data, value)` | `read_u16(data)` |
| u32 | `write_u32(data, value)` | `read_u32(data)` |
| u64 | `write_u64(data, value)` | `read_u64(data)` |
| u128 | `write_u128(data, value)` | `read_u128(data)` |
| u256 | `write_u256(data, value)` | `read_u256(data)` |
| i8 | `write_i8(data, value)` | `read_i8(data)` |
| i16 | `write_i16(data, value)` | `read_i16(data)` |
| i32 | `write_i32(data, value)` | `read_i32(data)` |
| i64 | `write_i64(data, value)` | `read_i64(data)` |
| i128 | `write_i128(data, value)` | `read_i128(data)` |
| i256 | `write_i256(data, value)` | `read_i256(data)` |
| bytes | `write_bytes(data, value)` | `read_bytes(data)` |
| string | `write_string(data, value)` | `read_string(data)` |
| fixed bytes | `write_fixed_bytes(data, value, len)` | `read_fixed_bytes(data, len)` |
| option | `write_option(data, value, ser_fn)` | `read_option(data, des_fn)` |
| vector | `write_vector(data, values, ser_fn)` | `read_vector(data, des_fn)` |
| map | `write_map(data, map, key_fn, val_fn)` | `read_map(data, key_fn, val_fn)` |
| ULEB128 | `write_uleb128(data, value)` | `read_uleb128(data)` |

### Error Handling

Deserializer functions come in two variants:

- `read_*` - Returns `{:ok, {value, rest}}` or `{:error, %Bcs.Error{}}`
- `read_*!` - Returns `{value, rest}` or raises `Bcs.Error`

```elixir
# Safe version with pattern matching
case Deserializer.read_bool(data) do
  {:ok, {value, rest}} -> 
    # Success
  {:error, %Bcs.Error{type: :invalid_boolean}} -> 
    # Handle error
end

# Raising version for pipelines
{value, rest} = Deserializer.read_bool!(data)
```

### Complex Types

#### Options

```elixir
# Serialize Some(42)
data = Serializer.write_option(<<>>, 42, &Serializer.write_u64/2)

# Serialize None
data = Serializer.write_option(<<>>, nil, &Serializer.write_u64/2)

# Deserialize
{value, rest} = Deserializer.read_option!(data, &Deserializer.read_u64/1)
# value is 42 or nil
```

#### Vectors

```elixir
# Serialize a list of u8
data = Serializer.write_vector(<<>>, [1, 2, 3], &Serializer.write_u8/2)

# Nested vectors
data = Serializer.write_vector(<<>>, [[1, 2], [3, 4]], fn acc, inner ->
  Serializer.write_vector(acc, inner, &Serializer.write_u8/2)
end)

# Deserialize
{values, rest} = Deserializer.read_vector!(data, &Deserializer.read_u8/1)
```

#### Structs

```elixir
# Serialize a Transfer struct manually
defmodule Transfer do
  defstruct [:sender, :recipient, :amount]

  def serialize(%__MODULE__{} = t) do
    Bcs.Serializer.new()
    |> Bcs.Serializer.enter_struct("Transfer")
    |> Bcs.Serializer.write_fixed_bytes(t.sender, 32)
    |> Bcs.Serializer.write_fixed_bytes(t.recipient, 32)
    |> Bcs.Serializer.write_u64(t.amount)
    |> Bcs.Serializer.leave_struct()
    |> Bcs.Serializer.to_bytes()
  end

  def deserialize(data) do
    state =
      data
      |> Bcs.Deserializer.new()
      |> Bcs.Deserializer.enter_struct("Transfer")

    {sender, state} = Bcs.Deserializer.read_fixed_bytes!(state, 32)
    {recipient, state} = Bcs.Deserializer.read_fixed_bytes!(state, 32)
    {amount, state} = Bcs.Deserializer.read_u64!(state)

    state
    |> Bcs.Deserializer.leave_struct()
    |> Bcs.Deserializer.check_end!()
    
    %__MODULE__{sender: sender, recipient: recipient, amount: amount}
  end
end
```

#### Enums

```elixir
# Serialize enum variant at index 1 with u64 data
data =
  Serializer.new()
  |> Serializer.enter_enum(1)
  |> Serializer.write_u64(42)
  |> Serializer.leave_enum()
  |> Serializer.to_bytes()

# Deserialize
{:ok, {index, d}} = Deserializer.enter_enum(Deserializer.new(data))
case index do
  0 -> # Handle variant 0
  1 -> 
    {value, d} = Deserializer.read_u64!(d)
    # Handle variant 1 with value
end
Deserializer.leave_enum(d) |> Deserializer.check_end!()
```

### ULEB128 Utilities

```elixir
alias Bcs.Uleb128

# Encode
encoded = Uleb128.encode(12345)  # <<0xB9, 0x60>>

# Decode
{value, rest} = Uleb128.decode!(encoded)  # {12345, <<>>}

# Get encoded size
size = Uleb128.encoded_size(12345)  # 2
```

## Elixir-Native Features

Elixir's binary pattern matching makes BCS particularly elegant:

```elixir
# Direct binary pattern matching for simple cases
<<tag::8, value::64-little, rest::binary>> = data
```

Arbitrary precision integers are native to Elixir, so u128/u256/i128/i256 work seamlessly.

## Development

```bash
# Install dependencies
mix deps.get

# Run tests
make test

# Format code
make format

# Lint
make lint

# Type checking
make dialyzer
```

## License

Apache-2.0
