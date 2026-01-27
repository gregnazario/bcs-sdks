defmodule Bcs do
  import Bitwise

  @moduledoc """
  Binary Canonical Serialization (BCS) for Elixir.

  BCS is a deterministic binary serialization format that guarantees
  canonical representation - every value has exactly one valid encoding.

  This library provides two APIs:

  ## Manual API

  Explicit control over serialization using `Bcs.Serializer` and `Bcs.Deserializer`:

      alias Bcs.{Serializer, Deserializer}

      # Serialization
      data =
        Serializer.new()
        |> Serializer.write_u8(1)
        |> Serializer.write_u64(100)
        |> Serializer.write_string("hello")
        |> Serializer.to_bytes()

      # Deserialization
      {value1, rest} = Deserializer.read_u8!(data)
      {value2, rest} = Deserializer.read_u64!(rest)
      {value3, rest} = Deserializer.read_string!(rest)
      Deserializer.check_end!(rest)

  ## Idiomatic API (coming soon)

  Using structs with the `Bcs.Struct` DSL:

      defmodule Transfer do
        use Bcs.Struct

        bcs_struct do
          field :sender, {:fixed_bytes, 32}
          field :recipient, {:fixed_bytes, 32}
          field :amount, :u64
        end
      end

      transfer = %Transfer{sender: addr1, recipient: addr2, amount: 1000}
      data = Bcs.serialize(transfer)
      {:ok, transfer2} = Bcs.deserialize(Transfer, data)

  ## Supported Types

  - Booleans: `bool`
  - Unsigned integers: `u8`, `u16`, `u32`, `u64`, `u128`, `u256`
  - Signed integers: `i8`, `i16`, `i32`, `i64`, `i128`, `i256`
  - Byte arrays: `bytes` (length-prefixed)
  - Strings: `string` (UTF-8, length-prefixed)
  - Fixed bytes: `{:fixed_bytes, length}`
  - Options: `{:option, inner_type}`
  - Vectors: `{:vector, element_type}`
  - Maps: `{:map, key_type, value_type}`
  - Enums: via variant index

  ## Constants

  - `MAX_SEQUENCE_LENGTH`: 2^31 - 1 (2,147,483,647)
  - `MAX_CONTAINER_DEPTH`: 500

  """

  @max_sequence_length (1 <<< 31) - 1
  @max_container_depth 500

  @doc """
  Maximum allowed sequence length.
  """
  @spec max_sequence_length() :: non_neg_integer()
  def max_sequence_length, do: @max_sequence_length

  @doc """
  Maximum allowed container nesting depth.
  """
  @spec max_container_depth() :: non_neg_integer()
  def max_container_depth, do: @max_container_depth

  # Re-export commonly used modules
  defdelegate serialize_u8(value), to: __MODULE__.Convenience
  defdelegate serialize_u64(value), to: __MODULE__.Convenience
  defdelegate serialize_string(value), to: __MODULE__.Convenience
  defdelegate serialize_bytes(value), to: __MODULE__.Convenience

  defdelegate deserialize_u8(data), to: __MODULE__.Convenience
  defdelegate deserialize_u64(data), to: __MODULE__.Convenience
  defdelegate deserialize_string(data), to: __MODULE__.Convenience
  defdelegate deserialize_bytes(data), to: __MODULE__.Convenience
end

defmodule Bcs.Convenience do
  @moduledoc false
  # Convenience functions for common operations

  alias Bcs.{Deserializer, Serializer}

  @doc """
  Serialize a u8 value.
  """
  @spec serialize_u8(non_neg_integer()) :: binary()
  def serialize_u8(value) do
    Serializer.new()
    |> Serializer.write_u8(value)
    |> Serializer.to_bytes()
  end

  @doc """
  Serialize a u64 value.
  """
  @spec serialize_u64(non_neg_integer()) :: binary()
  def serialize_u64(value) do
    Serializer.new()
    |> Serializer.write_u64(value)
    |> Serializer.to_bytes()
  end

  @doc """
  Serialize a string value.
  """
  @spec serialize_string(String.t()) :: binary()
  def serialize_string(value) do
    Serializer.new()
    |> Serializer.write_string(value)
    |> Serializer.to_bytes()
  end

  @doc """
  Serialize a bytes value.
  """
  @spec serialize_bytes(binary()) :: binary()
  def serialize_bytes(value) do
    Serializer.new()
    |> Serializer.write_bytes(value)
    |> Serializer.to_bytes()
  end

  @doc """
  Deserialize a u8 value.
  """
  @spec deserialize_u8(binary()) :: {:ok, non_neg_integer()} | {:error, Bcs.Error.t()}
  def deserialize_u8(data) do
    with {:ok, {value, rest}} <- Deserializer.read_u8(data),
         :ok <- Deserializer.check_end(rest) do
      {:ok, value}
    end
  end

  @doc """
  Deserialize a u64 value.
  """
  @spec deserialize_u64(binary()) :: {:ok, non_neg_integer()} | {:error, Bcs.Error.t()}
  def deserialize_u64(data) do
    with {:ok, {value, rest}} <- Deserializer.read_u64(data),
         :ok <- Deserializer.check_end(rest) do
      {:ok, value}
    end
  end

  @doc """
  Deserialize a string value.
  """
  @spec deserialize_string(binary()) :: {:ok, String.t()} | {:error, Bcs.Error.t()}
  def deserialize_string(data) do
    with {:ok, {value, rest}} <- Deserializer.read_string(data),
         :ok <- Deserializer.check_end(rest) do
      {:ok, value}
    end
  end

  @doc """
  Deserialize a bytes value.
  """
  @spec deserialize_bytes(binary()) :: {:ok, binary()} | {:error, Bcs.Error.t()}
  def deserialize_bytes(data) do
    with {:ok, {value, rest}} <- Deserializer.read_bytes(data),
         :ok <- Deserializer.check_end(rest) do
      {:ok, value}
    end
  end
end
