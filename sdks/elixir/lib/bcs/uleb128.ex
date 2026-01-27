defmodule Bcs.Uleb128 do
  import Bitwise

  @moduledoc """
  ULEB128 encoding and decoding for BCS.

  ULEB128 (Unsigned Little-Endian Base 128) is a variable-length encoding
  for unsigned integers. Each byte contributes 7 bits of data, with the
  high bit indicating whether more bytes follow.
  """

  alias Bcs.Error

  # Compile-time optimizations for hot path functions
  @compile {:inline, encode: 1, decode: 1}

  # Maximum value that can be encoded (u32 max)
  @max_u32 0xFFFFFFFF

  @doc """
  Encode an unsigned integer as ULEB128.

  ## Examples

      iex> Bcs.Uleb128.encode(0)
      <<0x00>>

      iex> Bcs.Uleb128.encode(127)
      <<0x7F>>

      iex> Bcs.Uleb128.encode(128)
      <<0x80, 0x01>>

      iex> Bcs.Uleb128.encode(16384)
      <<0x80, 0x80, 0x01>>

  """
  @spec encode(non_neg_integer()) :: binary()
  # Optimized paths for common small values (1-2 bytes covers most sequence lengths)
  def encode(value) when value >= 0 and value < 0x80, do: <<value>>
  def encode(value) when value < 0x4000, do: <<(value &&& 0x7F) ||| 0x80, value >>> 7>>

  def encode(value) when value < 0x200000,
    do: <<(value &&& 0x7F) ||| 0x80, ((value >>> 7) &&& 0x7F) ||| 0x80, value >>> 14>>

  def encode(value) when value < 0x10000000,
    do:
      <<(value &&& 0x7F) ||| 0x80, ((value >>> 7) &&& 0x7F) ||| 0x80,
        ((value >>> 14) &&& 0x7F) ||| 0x80, value >>> 21>>

  def encode(value) when value <= @max_u32,
    do:
      <<(value &&& 0x7F) ||| 0x80, ((value >>> 7) &&& 0x7F) ||| 0x80,
        ((value >>> 14) &&& 0x7F) ||| 0x80, ((value >>> 21) &&& 0x7F) ||| 0x80, value >>> 28>>

  def encode(value) when is_integer(value) and value < 0 do
    raise ArgumentError, "ULEB128 cannot encode negative values: #{value}"
  end

  def encode(value) when is_integer(value) do
    raise ArgumentError, "ULEB128 value exceeds u32 max: #{value}"
  end

  @doc """
  Decode a ULEB128 value from binary data.

  Returns `{:ok, {value, rest}}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> Bcs.Uleb128.decode(<<0x00>>)
      {:ok, {0, <<>>}}

      iex> Bcs.Uleb128.decode(<<0x7F>>)
      {:ok, {127, <<>>}}

      iex> Bcs.Uleb128.decode(<<0x80, 0x01>>)
      {:ok, {128, <<>>}}

      iex> Bcs.Uleb128.decode(<<0x80, 0x01, 0xFF>>)
      {:ok, {128, <<0xFF>>}}

  """
  @spec decode(binary()) :: {:ok, {non_neg_integer(), binary()}} | {:error, Error.t()}
  # Optimized fast paths for common 1-2 byte values
  def decode(<<byte, rest::binary>>) when byte < 0x80 do
    {:ok, {byte, rest}}
  end

  def decode(<<b0, b1, rest::binary>>) when b0 >= 0x80 and b1 < 0x80 do
    if b1 == 0, do: {:error, Error.non_canonical_uleb128()}, else: {:ok, {(b0 &&& 0x7F) ||| (b1 <<< 7), rest}}
  end

  def decode(<<b0, b1, b2, rest::binary>>) when b0 >= 0x80 and b1 >= 0x80 and b2 < 0x80 do
    if b2 == 0,
      do: {:error, Error.non_canonical_uleb128()},
      else: {:ok, {(b0 &&& 0x7F) ||| ((b1 &&& 0x7F) <<< 7) ||| (b2 <<< 14), rest}}
  end

  def decode(<<b0, b1, b2, b3, rest::binary>>)
      when b0 >= 0x80 and b1 >= 0x80 and b2 >= 0x80 and b3 < 0x80 do
    if b3 == 0,
      do: {:error, Error.non_canonical_uleb128()},
      else:
        {:ok,
         {(b0 &&& 0x7F) ||| ((b1 &&& 0x7F) <<< 7) ||| ((b2 &&& 0x7F) <<< 14) ||| (b3 <<< 21),
          rest}}
  end

  def decode(<<b0, b1, b2, b3, b4, rest::binary>>)
      when b0 >= 0x80 and b1 >= 0x80 and b2 >= 0x80 and b3 >= 0x80 and b4 < 0x10 do
    value =
      (b0 &&& 0x7F) ||| ((b1 &&& 0x7F) <<< 7) ||| ((b2 &&& 0x7F) <<< 14) |||
        ((b3 &&& 0x7F) <<< 21) ||| (b4 <<< 28)

    if value > @max_u32, do: {:error, Error.uleb128_overflow()}, else: {:ok, {value, rest}}
  end

  # 5th byte with continuation bit or too large
  def decode(<<b0, b1, b2, b3, _b4, _rest::binary>>)
      when b0 >= 0x80 and b1 >= 0x80 and b2 >= 0x80 and b3 >= 0x80 do
    {:error, Error.uleb128_overflow()}
  end

  # Unexpected EOF cases
  def decode(<<b0>>) when b0 >= 0x80, do: {:error, Error.unexpected_eof()}
  def decode(<<b0, b1>>) when b0 >= 0x80 and b1 >= 0x80, do: {:error, Error.unexpected_eof()}

  def decode(<<b0, b1, b2>>) when b0 >= 0x80 and b1 >= 0x80 and b2 >= 0x80,
    do: {:error, Error.unexpected_eof()}

  def decode(<<b0, b1, b2, b3>>) when b0 >= 0x80 and b1 >= 0x80 and b2 >= 0x80 and b3 >= 0x80,
    do: {:error, Error.unexpected_eof()}

  def decode(<<>>), do: {:error, Error.unexpected_eof()}

  @doc """
  Decode a ULEB128 value, raising on error.

  ## Examples

      iex> Bcs.Uleb128.decode!(<<0x80, 0x01>>)
      {128, <<>>}

  """
  @spec decode!(binary()) :: {non_neg_integer(), binary()}
  def decode!(data) do
    case decode(data) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Calculate the number of bytes needed to encode a value.

  ## Examples

      iex> Bcs.Uleb128.encoded_size(0)
      1

      iex> Bcs.Uleb128.encoded_size(127)
      1

      iex> Bcs.Uleb128.encoded_size(128)
      2

      iex> Bcs.Uleb128.encoded_size(16384)
      3

  """
  @spec encoded_size(non_neg_integer()) :: pos_integer()
  def encoded_size(0), do: 1

  def encoded_size(value) when is_integer(value) and value > 0 do
    do_encoded_size(value, 0)
  end

  defp do_encoded_size(0, count), do: count
  defp do_encoded_size(value, count), do: do_encoded_size(Bitwise.bsr(value, 7), count + 1)
end
