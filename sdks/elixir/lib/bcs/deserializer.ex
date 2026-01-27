defmodule Bcs.Deserializer do
  import Bitwise

  @moduledoc """
  BCS Deserializer - Manual deserialization API.

  Provides explicit functions for deserializing each BCS type.
  Use this for full control over deserialization.

  ## Example

      iex> alias Bcs.Deserializer, as: D
      iex> data = <<1, 100, 0, 0, 0, 0, 0, 0, 0, 5, 104, 101, 108, 108, 111>>
      iex> {:ok, {value1, rest}} = D.read_u8(data)
      iex> {value2, rest} = D.read_u64!(rest)
      iex> {value3, _rest} = D.read_string!(rest)
      iex> {value1, value2, value3}
      {1, 100, "hello"}

  """

  alias Bcs.{Error, Uleb128}

  # Constants
  @max_sequence_length (1 <<< 31) - 1
  @max_container_depth 500

  defstruct data: <<>>, depth: 0, max_depth: @max_container_depth

  @type t :: %__MODULE__{
          data: binary(),
          depth: non_neg_integer(),
          max_depth: non_neg_integer()
        }

  @type data_t :: binary() | t()

  # ==========================================================================
  # BOOLEAN
  # ==========================================================================

  @doc """
  Deserialize a boolean value.

  ## Examples

      iex> Bcs.Deserializer.read_bool(<<0>>)
      {:ok, {false, <<>>}}

      iex> Bcs.Deserializer.read_bool(<<1>>)
      {:ok, {true, <<>>}}

      iex> {:error, error} = Bcs.Deserializer.read_bool(<<2>>)
      iex> error.type
      :invalid_boolean

  """
  @spec read_bool(binary()) :: {:ok, {boolean(), binary()}} | {:error, Error.t()}
  def read_bool(%__MODULE__{} = state), do: wrap_state_result(state, read_bool(state.data))
  def read_bool(<<0, rest::binary>>), do: {:ok, {false, rest}}
  def read_bool(<<1, rest::binary>>), do: {:ok, {true, rest}}
  def read_bool(<<byte, _rest::binary>>), do: {:error, Error.invalid_boolean(byte)}
  def read_bool(<<>>), do: {:error, Error.unexpected_eof()}

  @doc """
  Deserialize a boolean value, raising on error.
  """
  @spec read_bool!(binary()) :: {boolean(), binary()}
  def read_bool!(data) do
    case read_bool(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # ==========================================================================
  # UNSIGNED INTEGERS
  # ==========================================================================

  @doc """
  Deserialize an unsigned 8-bit integer.
  """
  @spec read_u8(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_u8(%__MODULE__{} = state), do: wrap_state_result(state, read_u8(state.data))
  def read_u8(<<value::8, rest::binary>>), do: {:ok, {value, rest}}
  def read_u8(<<>>), do: {:error, Error.unexpected_eof()}

  @spec read_u8!(binary()) :: {non_neg_integer(), binary()}
  def read_u8!(data) do
    case read_u8(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize an unsigned 16-bit integer (little-endian).
  """
  @spec read_u16(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_u16(%__MODULE__{} = state), do: wrap_state_result(state, read_u16(state.data))
  def read_u16(<<value::16-little, rest::binary>>), do: {:ok, {value, rest}}

  def read_u16(data) when byte_size(data) < 2,
    do: {:error, Error.unexpected_eof(2, byte_size(data))}

  @spec read_u16!(binary()) :: {non_neg_integer(), binary()}
  def read_u16!(data) do
    case read_u16(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize an unsigned 32-bit integer (little-endian).
  """
  @spec read_u32(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_u32(%__MODULE__{} = state), do: wrap_state_result(state, read_u32(state.data))
  def read_u32(<<value::32-little, rest::binary>>), do: {:ok, {value, rest}}

  def read_u32(data) when byte_size(data) < 4,
    do: {:error, Error.unexpected_eof(4, byte_size(data))}

  @spec read_u32!(binary()) :: {non_neg_integer(), binary()}
  def read_u32!(data) do
    case read_u32(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize an unsigned 64-bit integer (little-endian).
  """
  @spec read_u64(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_u64(%__MODULE__{} = state), do: wrap_state_result(state, read_u64(state.data))
  def read_u64(<<value::64-little, rest::binary>>), do: {:ok, {value, rest}}

  def read_u64(data) when byte_size(data) < 8,
    do: {:error, Error.unexpected_eof(8, byte_size(data))}

  @spec read_u64!(binary()) :: {non_neg_integer(), binary()}
  def read_u64!(data) do
    case read_u64(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize an unsigned 128-bit integer (little-endian).
  """
  @spec read_u128(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_u128(%__MODULE__{} = state), do: wrap_state_result(state, read_u128(state.data))
  def read_u128(<<value::128-little, rest::binary>>), do: {:ok, {value, rest}}

  def read_u128(data) when byte_size(data) < 16,
    do: {:error, Error.unexpected_eof(16, byte_size(data))}

  @spec read_u128!(binary()) :: {non_neg_integer(), binary()}
  def read_u128!(data) do
    case read_u128(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize an unsigned 256-bit integer (little-endian).
  """
  @spec read_u256(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_u256(%__MODULE__{} = state), do: wrap_state_result(state, read_u256(state.data))
  def read_u256(<<value::256-little, rest::binary>>), do: {:ok, {value, rest}}

  def read_u256(data) when byte_size(data) < 32,
    do: {:error, Error.unexpected_eof(32, byte_size(data))}

  @spec read_u256!(binary()) :: {non_neg_integer(), binary()}
  def read_u256!(data) do
    case read_u256(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # ==========================================================================
  # SIGNED INTEGERS (two's complement)
  # ==========================================================================

  @doc """
  Deserialize a signed 8-bit integer (two's complement).
  """
  @spec read_i8(binary()) :: {:ok, {integer(), binary()}} | {:error, Error.t()}
  def read_i8(%__MODULE__{} = state), do: wrap_state_result(state, read_i8(state.data))
  def read_i8(<<value::8-signed, rest::binary>>), do: {:ok, {value, rest}}
  def read_i8(<<>>), do: {:error, Error.unexpected_eof()}

  @spec read_i8!(binary()) :: {integer(), binary()}
  def read_i8!(data) do
    case read_i8(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize a signed 16-bit integer (two's complement, little-endian).
  """
  @spec read_i16(binary()) :: {:ok, {integer(), binary()}} | {:error, Error.t()}
  def read_i16(%__MODULE__{} = state), do: wrap_state_result(state, read_i16(state.data))
  def read_i16(<<value::16-little-signed, rest::binary>>), do: {:ok, {value, rest}}

  def read_i16(data) when byte_size(data) < 2,
    do: {:error, Error.unexpected_eof(2, byte_size(data))}

  @spec read_i16!(binary()) :: {integer(), binary()}
  def read_i16!(data) do
    case read_i16(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize a signed 32-bit integer (two's complement, little-endian).
  """
  @spec read_i32(binary()) :: {:ok, {integer(), binary()}} | {:error, Error.t()}
  def read_i32(%__MODULE__{} = state), do: wrap_state_result(state, read_i32(state.data))
  def read_i32(<<value::32-little-signed, rest::binary>>), do: {:ok, {value, rest}}

  def read_i32(data) when byte_size(data) < 4,
    do: {:error, Error.unexpected_eof(4, byte_size(data))}

  @spec read_i32!(binary()) :: {integer(), binary()}
  def read_i32!(data) do
    case read_i32(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize a signed 64-bit integer (two's complement, little-endian).
  """
  @spec read_i64(binary()) :: {:ok, {integer(), binary()}} | {:error, Error.t()}
  def read_i64(%__MODULE__{} = state), do: wrap_state_result(state, read_i64(state.data))
  def read_i64(<<value::64-little-signed, rest::binary>>), do: {:ok, {value, rest}}

  def read_i64(data) when byte_size(data) < 8,
    do: {:error, Error.unexpected_eof(8, byte_size(data))}

  @spec read_i64!(binary()) :: {integer(), binary()}
  def read_i64!(data) do
    case read_i64(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize a signed 128-bit integer (two's complement, little-endian).
  """
  @spec read_i128(binary()) :: {:ok, {integer(), binary()}} | {:error, Error.t()}
  def read_i128(%__MODULE__{} = state), do: wrap_state_result(state, read_i128(state.data))
  def read_i128(<<value::128-little-signed, rest::binary>>), do: {:ok, {value, rest}}

  def read_i128(data) when byte_size(data) < 16,
    do: {:error, Error.unexpected_eof(16, byte_size(data))}

  @spec read_i128!(binary()) :: {integer(), binary()}
  def read_i128!(data) do
    case read_i128(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize a signed 256-bit integer (two's complement, little-endian).
  """
  @spec read_i256(binary()) :: {:ok, {integer(), binary()}} | {:error, Error.t()}
  def read_i256(%__MODULE__{} = state), do: wrap_state_result(state, read_i256(state.data))
  def read_i256(<<value::256-little-signed, rest::binary>>), do: {:ok, {value, rest}}

  def read_i256(data) when byte_size(data) < 32,
    do: {:error, Error.unexpected_eof(32, byte_size(data))}

  @spec read_i256!(binary()) :: {integer(), binary()}
  def read_i256!(data) do
    case read_i256(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # ==========================================================================
  # ULEB128
  # ==========================================================================

  @doc """
  Deserialize a ULEB128-encoded unsigned integer.
  """
  @spec read_uleb128(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_uleb128(%__MODULE__{} = state), do: wrap_state_result(state, Uleb128.decode(state.data))
  def read_uleb128(data), do: Uleb128.decode(data)

  @spec read_uleb128!(binary()) :: {non_neg_integer(), binary()}
  def read_uleb128!(data), do: Uleb128.decode!(data)

  # ==========================================================================
  # BYTES AND STRINGS
  # ==========================================================================

  @doc """
  Deserialize a byte array (length-prefixed with ULEB128).
  """
  @spec read_bytes(binary()) :: {:ok, {binary(), binary()}} | {:error, Error.t()}
  def read_bytes(data) do
    with {:ok, {length, rest}} <- read_uleb128(data) do
      if length > @max_sequence_length do
        {:error, Error.exceeded_max_length(length)}
      else
        read_fixed_bytes(rest, length)
      end
    end
  end

  @spec read_bytes!(binary()) :: {binary(), binary()}
  def read_bytes!(data) do
    case read_bytes(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize a UTF-8 string (length-prefixed with ULEB128).
  """
  @spec read_string(binary()) :: {:ok, {String.t(), binary()}} | {:error, Error.t()}
  def read_string(data) do
    with {:ok, {bytes, rest}} <- read_bytes(data) do
      if String.valid?(bytes) do
        {:ok, {bytes, rest}}
      else
        {:error, Error.invalid_utf8()}
      end
    end
  end

  @spec read_string!(binary()) :: {String.t(), binary()}
  def read_string!(data) do
    case read_string(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Deserialize fixed-length bytes (no length prefix).
  """
  @spec read_fixed_bytes(binary(), non_neg_integer()) ::
          {:ok, {binary(), binary()}} | {:error, Error.t()}
  def read_fixed_bytes(%__MODULE__{data: data} = state, length) do
    if byte_size(data) >= length do
      <<bytes::binary-size(length), rest::binary>> = data
      {:ok, {bytes, %{state | data: rest}}}
    else
      {:error, Error.unexpected_eof(length, byte_size(data))}
    end
  end

  def read_fixed_bytes(data, length) when byte_size(data) >= length do
    <<bytes::binary-size(length), rest::binary>> = data
    {:ok, {bytes, rest}}
  end

  def read_fixed_bytes(data, length) do
    {:error, Error.unexpected_eof(length, byte_size(data))}
  end

  @spec read_fixed_bytes!(binary(), non_neg_integer()) :: {binary(), binary()}
  def read_fixed_bytes!(data, length) do
    case read_fixed_bytes(data, length) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # ==========================================================================
  # OPTION
  # ==========================================================================

  @doc """
  Deserialize an optional value.

  ## Examples

      iex> Bcs.Deserializer.read_option(<<0>>, &Bcs.Deserializer.read_u8/1)
      {:ok, {nil, <<>>}}

      iex> Bcs.Deserializer.read_option(<<1, 42>>, &Bcs.Deserializer.read_u8/1)
      {:ok, {42, <<>>}}

  """
  @spec read_option(binary(), (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()})) ::
          {:ok, {any() | nil, binary()}} | {:error, Error.t()}
  def read_option(%__MODULE__{data: <<0, rest::binary>>} = state, _deserializer) do
    {:ok, {nil, %{state | data: rest}}}
  end

  def read_option(%__MODULE__{data: <<1, rest::binary>>} = state, deserializer) do
    deserializer.(%{state | data: rest})
  end

  def read_option(%__MODULE__{data: <<tag, _rest::binary>>}, _deserializer) do
    {:error, Error.invalid_option(tag)}
  end

  def read_option(%__MODULE__{data: <<>>}, _deserializer) do
    {:error, Error.unexpected_eof()}
  end

  def read_option(<<0, rest::binary>>, _deserializer) do
    {:ok, {nil, rest}}
  end

  def read_option(<<1, rest::binary>>, deserializer) do
    deserializer.(rest)
  end

  def read_option(<<tag, _rest::binary>>, _deserializer) do
    {:error, Error.invalid_option(tag)}
  end

  def read_option(<<>>, _deserializer) do
    {:error, Error.unexpected_eof()}
  end

  @spec read_option!(binary(), (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()})) ::
          {any() | nil, binary()}
  def read_option!(data, deserializer) do
    case read_option(data, deserializer) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # ==========================================================================
  # VECTOR
  # ==========================================================================

  @doc """
  Deserialize a vector of values.

  ## Examples

      iex> Bcs.Deserializer.read_vector(<<3, 1, 2, 3>>, &Bcs.Deserializer.read_u8/1)
      {:ok, {[1, 2, 3], <<>>}}

  """
  @spec read_vector(binary(), (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()})) ::
          {:ok, {list(), binary()}} | {:error, Error.t()}
  def read_vector(data, deserializer) do
    with {:ok, {length, rest}} <- read_uleb128(data) do
      if length > @max_sequence_length do
        {:error, Error.exceeded_max_length(length)}
      else
        read_vector_elements(rest, length, deserializer, [])
      end
    end
  end

  defp read_vector_elements(rest, 0, _deserializer, acc) do
    {:ok, {Enum.reverse(acc), rest}}
  end

  defp read_vector_elements(data, count, deserializer, acc) do
    case deserializer.(data) do
      {:ok, {value, rest}} ->
        read_vector_elements(rest, count - 1, deserializer, [value | acc])

      {:error, _} = error ->
        error
    end
  end

  @spec read_vector!(binary(), (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()})) ::
          {list(), binary()}
  def read_vector!(data, deserializer) do
    case read_vector(data, deserializer) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # ==========================================================================
  # ENUM
  # ==========================================================================

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
  Enter an enum container for depth tracking and read its variant index (ULEB128).
  """
  @spec enter_enum(t()) :: {:ok, {non_neg_integer(), t()}} | {:error, Error.t()}
  def enter_enum(%__MODULE__{} = data) do
    data
    |> check_depth("enum")
    |> read_uleb128()
  end

  @doc """
  Leave the current enum container.
  """
  @spec leave_enum(t()) :: t()
  def leave_enum(%__MODULE__{} = data) do
    leave_container(data)
  end

  @doc """
  Read an enum variant index (ULEB128).
  """
  @spec read_variant_index(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  def read_variant_index(%__MODULE__{} = data), do: enter_enum(data)
  def read_variant_index(data), do: read_uleb128(data)

  @spec read_variant_index!(binary()) :: {non_neg_integer(), binary()}
  def read_variant_index!(data), do: read_uleb128!(data)

  # ==========================================================================
  # MAP
  # ==========================================================================

  @doc """
  Deserialize a map (verifying sorted keys).
  """
  @spec read_map(
          binary(),
          (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()}),
          (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()})
        ) :: {:ok, {map(), binary()}} | {:error, Error.t()}
  def read_map(data, key_deserializer, value_deserializer) do
    with {:ok, {length, rest}} <- read_uleb128(data) do
      if length > @max_sequence_length do
        {:error, Error.exceeded_max_length(length)}
      else
        read_map_entries(rest, length, key_deserializer, value_deserializer, nil, %{})
      end
    end
  end

  defp read_map_entries(rest, 0, _key_des, _val_des, _prev_key_bytes, acc) do
    {:ok, {acc, rest}}
  end

  defp read_map_entries(
         %__MODULE__{} = data,
         count,
         key_deserializer,
         value_deserializer,
         prev_key_bytes,
         acc
       ) do
    # Record start position to get key bytes
    key_start = data.data

    case key_deserializer.(data) do
      {:ok, {key, after_key}} ->
        # Calculate key bytes
        key_bytes_size = byte_size(key_start) - byte_size(after_key.data)
        <<key_bytes::binary-size(key_bytes_size), _::binary>> = key_start

        # Check sorted order
        if prev_key_bytes != nil and key_bytes <= prev_key_bytes do
          {:error, check_map_key_order_error(key_bytes, prev_key_bytes)}
        else
          read_map_entry_value(
            after_key,
            count,
            key,
            key_bytes,
            key_deserializer,
            value_deserializer,
            acc
          )
        end

      {:error, _} = error ->
        error
    end
  end

  defp read_map_entries(data, count, key_deserializer, value_deserializer, prev_key_bytes, acc) do
    # Record start position to get key bytes
    key_start = data

    case key_deserializer.(data) do
      {:ok, {key, after_key}} ->
        # Calculate key bytes
        key_bytes_size = byte_size(data) - byte_size(after_key)
        <<key_bytes::binary-size(key_bytes_size), _::binary>> = key_start

        # Check sorted order
        if prev_key_bytes != nil and key_bytes <= prev_key_bytes do
          {:error, check_map_key_order_error(key_bytes, prev_key_bytes)}
        else
          read_map_entry_value_binary(
            after_key,
            count,
            key,
            key_bytes,
            key_deserializer,
            value_deserializer,
            acc
          )
        end

      {:error, _} = error ->
        error
    end
  end

  defp read_map_entry_value(
         after_key,
         count,
         key,
         key_bytes,
         key_deserializer,
         value_deserializer,
         acc
       ) do
    case value_deserializer.(after_key) do
      {:ok, {value, rest}} ->
        read_map_entries(
          rest,
          count - 1,
          key_deserializer,
          value_deserializer,
          key_bytes,
          Map.put(acc, key, value)
        )

      {:error, _} = error ->
        error
    end
  end

  defp read_map_entry_value_binary(
         after_key,
         count,
         key,
         key_bytes,
         key_deserializer,
         value_deserializer,
         acc
       ) do
    case value_deserializer.(after_key) do
      {:ok, {value, rest}} ->
        read_map_entries(
          rest,
          count - 1,
          key_deserializer,
          value_deserializer,
          key_bytes,
          Map.put(acc, key, value)
        )

      {:error, _} = error ->
        error
    end
  end

  @spec read_map!(
          binary(),
          (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()}),
          (binary() -> {:ok, {any(), binary()}} | {:error, Error.t()})
        ) :: {map(), binary()}
  def read_map!(data, key_deserializer, value_deserializer) do
    case read_map(data, key_deserializer, value_deserializer) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # ==========================================================================
  # UTILITY
  # ==========================================================================

  @doc """
  Create a new deserializer state.
  """
  @spec new(binary()) :: t()
  def new(data) when is_binary(data), do: %__MODULE__{data: data}

  @doc """
  Check that all input has been consumed.
  """
  @spec check_end(binary()) :: :ok | {:error, Error.t()}
  def check_end(%__MODULE__{data: <<>>}), do: :ok
  def check_end(%__MODULE__{data: data}), do: {:error, Error.remaining_input(byte_size(data))}
  def check_end(<<>>), do: :ok
  def check_end(data), do: {:error, Error.remaining_input(byte_size(data))}

  @doc """
  Check that all input has been consumed, raising on error.
  """
  @spec check_end!(binary()) :: :ok
  def check_end!(%__MODULE__{data: <<>>}), do: :ok
  def check_end!(%__MODULE__{data: data}), do: raise(Error.remaining_input(byte_size(data)))
  def check_end!(<<>>), do: :ok
  def check_end!(data), do: raise(Error.remaining_input(byte_size(data)))

  @doc """
  Get the number of remaining bytes.
  """
  @spec remaining(binary()) :: non_neg_integer()
  def remaining(%__MODULE__{data: data}), do: byte_size(data)
  def remaining(data), do: byte_size(data)

  defp wrap_state_result(%__MODULE__{} = state, {:ok, {value, rest}}) do
    {:ok, {value, %{state | data: rest}}}
  end

  defp wrap_state_result(_state, {:error, _} = error), do: error

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

  defp check_map_key_order_error(key_bytes, prev_key_bytes) do
    error_type = if key_bytes == prev_key_bytes, do: "duplicate key", else: "keys not sorted"
    Error.non_canonical_map(error_type)
  end
end
