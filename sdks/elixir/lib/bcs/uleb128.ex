defmodule Bcs.Uleb128 do
  @moduledoc """
  ULEB128 encoding and decoding for BCS.

  ULEB128 (Unsigned Little-Endian Base 128) is a variable-length encoding
  for unsigned integers. Each byte contributes 7 bits of data, with the
  high bit indicating whether more bytes follow.
  """

  alias Bcs.Error

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
  def encode(value) when is_integer(value) and value >= 0 and value <= @max_u32 do
    do_encode(value, <<>>)
  end

  def encode(value) when is_integer(value) and value < 0 do
    raise ArgumentError, "ULEB128 cannot encode negative values: #{value}"
  end

  def encode(value) when is_integer(value) do
    raise ArgumentError, "ULEB128 value exceeds u32 max: #{value}"
  end

  defp do_encode(value, acc) when value < 0x80 do
    acc <> <<value>>
  end

  defp do_encode(value, acc) do
    byte = Bitwise.band(value, 0x7F) |> Bitwise.bor(0x80)
    do_encode(Bitwise.bsr(value, 7), acc <> <<byte>>)
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
  def decode(data) when is_binary(data) do
    do_decode(data, 0, 0, 0)
  end

  # Successfully decoded - check for non-canonical encoding
  defp do_decode(<<byte, rest::binary>>, value, shift, _count) when byte < 0x80 do
    final_value = Bitwise.bor(value, Bitwise.bsl(byte, shift))

    cond do
      # Non-canonical: trailing zero byte (except for value 0 at position 0)
      shift > 0 and byte == 0 ->
        {:error, Error.non_canonical_uleb128()}

      # Overflow check
      final_value > @max_u32 ->
        {:error, Error.uleb128_overflow()}

      true ->
        {:ok, {final_value, rest}}
    end
  end

  # Continue decoding
  defp do_decode(<<byte, rest::binary>>, value, shift, count) when count < 4 do
    digit = Bitwise.band(byte, 0x7F)
    new_value = Bitwise.bor(value, Bitwise.bsl(digit, shift))
    do_decode(rest, new_value, shift + 7, count + 1)
  end

  # 5th byte - must be final and small enough
  defp do_decode(<<byte, rest::binary>>, value, shift, 4) when byte < 0x10 do
    final_value = Bitwise.bor(value, Bitwise.bsl(byte, shift))

    if final_value > @max_u32 do
      {:error, Error.uleb128_overflow()}
    else
      {:ok, {final_value, rest}}
    end
  end

  # 5th byte with continuation bit or too large
  defp do_decode(<<_byte, _rest::binary>>, _value, _shift, 4) do
    {:error, Error.uleb128_overflow()}
  end

  # Unexpected EOF
  defp do_decode(<<>>, _value, _shift, _count) do
    {:error, Error.unexpected_eof()}
  end

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
