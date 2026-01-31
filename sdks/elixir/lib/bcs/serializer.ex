defmodule Bcs.Serializer do
  import Bitwise

  @moduledoc """
  BCS Serializer - Manual serialization API.

  Provides explicit functions for serializing each BCS type.
  Use this for full control over serialization.

  ## Example

      iex> alias Bcs.Serializer, as: S
      iex> <<>>
      ...> |> S.write_u8(1)
      ...> |> S.write_u64(100)
      ...> |> S.write_string("hello")
      <<1, 100, 0, 0, 0, 0, 0, 0, 0, 5, 104, 101, 108, 108, 111>>

  """

  alias Bcs.Error

  # Compile-time optimizations
  @compile {:inline,
            write_bool: 2,
            write_u8: 2,
            write_u16: 2,
            write_u32: 2,
            write_u64: 2,
            encode_uleb128: 1,
            append: 2}

  # Constants
  @max_sequence_length (1 <<< 31) - 1
  @max_container_depth 500

  @u8_max 0xFF
  @u16_max 0xFFFF
  @u32_max 0xFFFFFFFF
  @u64_max 0xFFFFFFFFFFFFFFFF
  @u128_max (1 <<< 128) - 1
  @u256_max (1 <<< 256) - 1

  @i8_min -128
  @i8_max 127
  @i16_min -32_768
  @i16_max 32_767
  @i32_min -2_147_483_648
  @i32_max 2_147_483_647
  @i64_min - (1 <<< 63)
  @i64_max (1 <<< 63) - 1
  @i128_min - (1 <<< 127)
  @i128_max (1 <<< 127) - 1
  @i256_min - (1 <<< 255)
  @i256_max (1 <<< 255) - 1

  # Using iodata for efficient accumulation, converted to binary on to_bytes/1
  defstruct data: [], depth: 0, max_depth: @max_container_depth

  @type t :: %__MODULE__{
          data: iodata(),
          depth: non_neg_integer(),
          max_depth: non_neg_integer()
        }

  @type data_t :: binary() | t()

  # ==========================================================================
  # BOOLEAN
  # ==========================================================================

  @doc """
  Serialize a boolean value.

  ## Examples

      iex> Bcs.Serializer.write_bool(<<>>, true)
      <<1>>

      iex> Bcs.Serializer.write_bool(<<>>, false)
      <<0>>

  """
  @spec write_bool(binary(), boolean()) :: binary()
  def write_bool(data, true), do: append(data, <<1>>)
  def write_bool(data, false), do: append(data, <<0>>)

  # ==========================================================================
  # UNSIGNED INTEGERS
  # ==========================================================================

  @doc """
  Serialize an unsigned 8-bit integer.
  """
  @spec write_u8(binary(), non_neg_integer()) :: binary()
  def write_u8(data, value) when is_integer(value) and value >= 0 and value <= @u8_max do
    append(data, <<value::8>>)
  end

  def write_u8(_data, value) do
    raise Error.value_out_of_range("u8", value)
  end

  @doc """
  Serialize an unsigned 16-bit integer (little-endian).
  """
  @spec write_u16(binary(), non_neg_integer()) :: binary()
  def write_u16(data, value) when is_integer(value) and value >= 0 and value <= @u16_max do
    append(data, <<value::16-little>>)
  end

  def write_u16(_data, value) do
    raise Error.value_out_of_range("u16", value)
  end

  @doc """
  Serialize an unsigned 32-bit integer (little-endian).
  """
  @spec write_u32(binary(), non_neg_integer()) :: binary()
  def write_u32(data, value) when is_integer(value) and value >= 0 and value <= @u32_max do
    append(data, <<value::32-little>>)
  end

  def write_u32(_data, value) do
    raise Error.value_out_of_range("u32", value)
  end

  @doc """
  Serialize an unsigned 64-bit integer (little-endian).
  """
  @spec write_u64(binary(), non_neg_integer()) :: binary()
  def write_u64(data, value) when is_integer(value) and value >= 0 and value <= @u64_max do
    append(data, <<value::64-little>>)
  end

  def write_u64(_data, value) do
    raise Error.value_out_of_range("u64", value)
  end

  @doc """
  Serialize an unsigned 128-bit integer (little-endian).
  """
  @spec write_u128(binary(), non_neg_integer()) :: binary()
  def write_u128(data, value) when is_integer(value) and value >= 0 and value <= @u128_max do
    append(data, <<value::128-little>>)
  end

  def write_u128(_data, value) do
    raise Error.value_out_of_range("u128", value)
  end

  @doc """
  Serialize an unsigned 256-bit integer (little-endian).
  """
  @spec write_u256(binary(), non_neg_integer()) :: binary()
  def write_u256(data, value) when is_integer(value) and value >= 0 and value <= @u256_max do
    append(data, <<value::256-little>>)
  end

  def write_u256(_data, value) do
    raise Error.value_out_of_range("u256", value)
  end

  # ==========================================================================
  # SIGNED INTEGERS (two's complement)
  # ==========================================================================

  @doc """
  Serialize a signed 8-bit integer (two's complement).
  """
  @spec write_i8(binary(), integer()) :: binary()
  def write_i8(data, value) when is_integer(value) and value >= @i8_min and value <= @i8_max do
    append(data, <<value::8-signed>>)
  end

  def write_i8(_data, value) do
    raise Error.value_out_of_range("i8", value)
  end

  @doc """
  Serialize a signed 16-bit integer (two's complement, little-endian).
  """
  @spec write_i16(binary(), integer()) :: binary()
  def write_i16(data, value) when is_integer(value) and value >= @i16_min and value <= @i16_max do
    append(data, <<value::16-little-signed>>)
  end

  def write_i16(_data, value) do
    raise Error.value_out_of_range("i16", value)
  end

  @doc """
  Serialize a signed 32-bit integer (two's complement, little-endian).
  """
  @spec write_i32(binary(), integer()) :: binary()
  def write_i32(data, value) when is_integer(value) and value >= @i32_min and value <= @i32_max do
    append(data, <<value::32-little-signed>>)
  end

  def write_i32(_data, value) do
    raise Error.value_out_of_range("i32", value)
  end

  @doc """
  Serialize a signed 64-bit integer (two's complement, little-endian).
  """
  @spec write_i64(binary(), integer()) :: binary()
  def write_i64(data, value) when is_integer(value) and value >= @i64_min and value <= @i64_max do
    append(data, <<value::64-little-signed>>)
  end

  def write_i64(_data, value) do
    raise Error.value_out_of_range("i64", value)
  end

  @doc """
  Serialize a signed 128-bit integer (two's complement, little-endian).
  """
  @spec write_i128(binary(), integer()) :: binary()
  def write_i128(data, value)
      when is_integer(value) and value >= @i128_min and value <= @i128_max do
    append(data, <<value::128-little-signed>>)
  end

  def write_i128(_data, value) do
    raise Error.value_out_of_range("i128", value)
  end

  @doc """
  Serialize a signed 256-bit integer (two's complement, little-endian).
  """
  @spec write_i256(binary(), integer()) :: binary()
  def write_i256(data, value)
      when is_integer(value) and value >= @i256_min and value <= @i256_max do
    append(data, <<value::256-little-signed>>)
  end

  def write_i256(_data, value) do
    raise Error.value_out_of_range("i256", value)
  end

  # ==========================================================================
  # ULEB128
  # ==========================================================================

  @doc """
  Serialize a ULEB128-encoded unsigned integer.
  """
  @spec write_uleb128(data_t(), non_neg_integer()) :: data_t()
  def write_uleb128(data, value) when value >= 0 and value <= @u32_max do
    append(data, encode_uleb128(value))
  end

  def write_uleb128(_data, value) when value < 0 do
    raise ArgumentError, "ULEB128 cannot encode negative values: #{value}"
  end

  def write_uleb128(_data, value) do
    raise ArgumentError, "ULEB128 value exceeds u32 max: #{value}"
  end

  # Delegate to Uleb128 module for encoding
  defp encode_uleb128(value), do: Bcs.Uleb128.encode(value)

  # ==========================================================================
  # BYTES AND STRINGS
  # ==========================================================================

  @doc """
  Serialize a byte array (length-prefixed with ULEB128).
  """
  @spec write_bytes(binary(), binary()) :: binary()
  def write_bytes(data, value) when is_binary(value) do
    len = byte_size(value)

    if len > @max_sequence_length do
      raise Error.exceeded_max_length(len)
    end

    data
    |> write_uleb128(len)
    |> append(value)
  end

  @doc """
  Serialize a UTF-8 string (length-prefixed with ULEB128).

  Raises if the string is not valid UTF-8.
  """
  @spec write_string(binary(), String.t()) :: binary()
  def write_string(data, value) when is_binary(value) do
    unless String.valid?(value) do
      raise Error.invalid_utf8()
    end

    write_bytes(data, value)
  end

  @doc """
  Serialize fixed-length bytes (no length prefix).
  """
  @spec write_fixed_bytes(binary(), binary(), non_neg_integer()) :: binary()
  def write_fixed_bytes(data, value, length)
      when is_binary(value) and byte_size(value) == length do
    append(data, value)
  end

  def write_fixed_bytes(_data, value, length) do
    raise ArgumentError, "Expected #{length} bytes, got #{byte_size(value)}"
  end

  # ==========================================================================
  # OPTION
  # ==========================================================================

  @doc """
  Serialize an optional value.

  ## Examples

      iex> Bcs.Serializer.write_option(<<>>, nil, &Bcs.Serializer.write_u8/2)
      <<0>>

      iex> Bcs.Serializer.write_option(<<>>, 42, &Bcs.Serializer.write_u8/2)
      <<1, 42>>

  """
  @spec write_option(binary(), any() | nil, (binary(), any() -> binary())) :: binary()
  def write_option(data, nil, _serializer) do
    append(data, <<0>>)
  end

  def write_option(data, value, serializer) do
    data
    |> append(<<1>>)
    |> serializer.(value)
  end

  # ==========================================================================
  # VECTOR
  # ==========================================================================

  @doc """
  Serialize a vector of values.

  ## Examples

      iex> Bcs.Serializer.write_vector(<<>>, [1, 2, 3], &Bcs.Serializer.write_u8/2)
      <<3, 1, 2, 3>>

  """
  @spec write_vector(data_t(), list(), (data_t(), any() -> data_t())) :: data_t()
  def write_vector(data, values, serializer) when is_list(values) do
    len = length(values)

    if len > @max_sequence_length do
      raise Error.exceeded_max_length(len)
    end

    data
    |> write_uleb128(len)
    |> then(fn d -> Enum.reduce(values, d, fn value, acc -> serializer.(acc, value) end) end)
  end

  @doc """
  Serialize a vector of u8 values (optimized).

  ## Examples

      iex> Bcs.Serializer.write_vector_u8(<<>>, [1, 2, 3])
      <<3, 1, 2, 3>>

  """
  @spec write_vector_u8(data_t(), list(non_neg_integer()) | binary()) :: data_t()
  def write_vector_u8(data, values) when is_binary(values) do
    len = byte_size(values)

    if len > @max_sequence_length do
      raise Error.exceeded_max_length(len)
    end

    data
    |> write_uleb128(len)
    |> append(values)
  end

  def write_vector_u8(data, values) when is_list(values) do
    len = length(values)

    if len > @max_sequence_length do
      raise Error.exceeded_max_length(len)
    end

    # Convert list of integers to binary directly
    bytes = :erlang.list_to_binary(values)

    data
    |> write_uleb128(len)
    |> append(bytes)
  end

  # ==========================================================================
  # ENUM
  # ==========================================================================

  @doc """
  Enter an enum container and write its variant index (ULEB128).
  """
  @spec write_variant_index(binary(), non_neg_integer()) :: binary()
  def write_variant_index(%__MODULE__{} = data, index) do
    enter_enum(data, index)
  end

  def write_variant_index(data, index) when is_binary(data) do
    write_uleb128(data, index)
  end

  @doc """
  Enter a struct container for depth tracking.
  """
  @spec enter_struct(t(), String.t()) :: t()
  def enter_struct(%__MODULE__{} = data, name \\ "") do
    check_depth(data, name)
  end

  @doc """
  Leave the current struct container.
  """
  @spec leave_struct(t()) :: t()
  def leave_struct(%__MODULE__{} = data) do
    leave_container(data)
  end

  @doc """
  Enter an enum container for depth tracking and write its variant index.
  """
  @spec enter_enum(t(), non_neg_integer()) :: t()
  def enter_enum(%__MODULE__{} = data, index) do
    data
    |> check_depth("enum")
    |> write_uleb128(index)
  end

  @doc """
  Leave the current enum container.
  """
  @spec leave_enum(t()) :: t()
  def leave_enum(%__MODULE__{} = data) do
    leave_container(data)
  end

  # ==========================================================================
  # MAP
  # ==========================================================================

  @doc """
  Serialize a map (sorted by key bytes).

  ## Examples

      iex> Bcs.Serializer.write_map(<<>>, %{1 => 10, 2 => 20}, &Bcs.Serializer.write_u8/2, &Bcs.Serializer.write_u8/2)
      <<2, 1, 10, 2, 20>>

  """
  @spec write_map(data_t(), map(), (data_t(), any() -> data_t()), (data_t(), any() -> data_t())) ::
          data_t()
  def write_map(data, items, key_serializer, value_serializer) when is_map(items) do
    len = map_size(items)

    if len > @max_sequence_length do
      raise Error.exceeded_max_length(len)
    end

    # Serialize keys to get bytes for sorting
    key_bytes_pairs =
      items
      |> Enum.map(fn {key, value} ->
        # Use binary mode for key serialization to get bytes for sorting
        key_bytes = key_serializer.(<<>>, key)
        {key_bytes, value}
      end)
      |> Enum.sort_by(fn {key_bytes, _value} -> key_bytes end)

    # Write length and sorted entries
    data
    |> write_uleb128(len)
    |> then(fn d ->
      Enum.reduce(key_bytes_pairs, d, fn {key_bytes, value}, acc ->
        acc
        |> append(key_bytes)
        |> value_serializer.(value)
      end)
    end)
  end

  # ==========================================================================
  # CONVENIENCE FUNCTIONS
  # ==========================================================================

  @doc """
  Create a new empty serializer buffer.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Get the serialized bytes.
  """
  @spec to_bytes(data_t()) :: binary()
  def to_bytes(%__MODULE__{data: data}), do: IO.iodata_to_binary(data)
  def to_bytes(data) when is_binary(data), do: data

  # Optimized append using IO lists for struct, binary concat for raw binary
  defp append(%__MODULE__{data: data} = state, bytes) do
    %{state | data: [data | bytes]}
  end

  defp append(data, bytes) when is_binary(data) and is_binary(bytes) do
    data <> bytes
  end

  defp check_depth(%__MODULE__{depth: depth, max_depth: max_depth} = state, container) do
    if depth >= max_depth do
      raise Error.exceeded_container_depth(container)
    end

    %{state | depth: depth + 1}
  end

  defp leave_container(%__MODULE__{depth: depth} = state) do
    next_depth = if depth > 0, do: depth - 1, else: 0
    %{state | depth: next_depth}
  end
end
