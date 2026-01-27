#!/usr/bin/env elixir
# Elixir BCS E2E Test Runner
#
# Reads test vectors from stdin, performs roundtrip serialization,
# and outputs results to stdout.
#
# Prerequisites: Run `mix deps.get && mix compile` in sdks/elixir first

# Add the SDK to the code path (must be compiled first)
sdk_path = Path.expand("../../sdks/elixir", __DIR__)
ebin_path = Path.join([sdk_path, "_build", "dev", "lib", "bcs", "ebin"])
jason_ebin = Path.join([sdk_path, "_build", "dev", "lib", "jason", "ebin"])

unless File.dir?(ebin_path) do
  IO.puts(:stderr, "Error: Elixir SDK not compiled. Run 'mix deps.get && mix compile' in sdks/elixir first.")
  System.halt(1)
end

Code.prepend_path(ebin_path)
Code.prepend_path(jason_ebin)

defmodule E2ERunner do
  @moduledoc """
  E2E test runner for Elixir BCS SDK.
  Uses the bang (!) methods that raise on error.
  """

  alias Bcs.{Deserializer, Serializer, Uleb128}

  def hex_to_bytes(hex) do
    Base.decode16!(hex, case: :lower)
  end

  def bytes_to_hex(bytes) do
    Base.encode16(bytes, case: :lower)
  end

  def process_test_case(test_case) do
    name = test_case["name"]
    type = test_case["type"]
    bcs_hex = test_case["bcs_hex"]

    try do
      data = hex_to_bytes(bcs_hex)
      result_hex = roundtrip(type, data, test_case)

      %{
        "name" => name,
        "type" => type,
        "bcs_hex" => result_hex,
        "value" => test_case["value"]
      }
    rescue
      e ->
        %{
          "name" => name,
          "type" => type,
          "bcs_hex" => "",
          "value" => test_case["value"],
          "error" => Exception.message(e)
        }
    end
  end

  # Use the bang methods that return {value, rest} directly

  defp roundtrip("bool", data, _tc) do
    {value, <<>>} = Deserializer.read_bool!(data)
    Serializer.new() |> Serializer.write_bool(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("u8", data, _tc) do
    {value, <<>>} = Deserializer.read_u8!(data)
    Serializer.new() |> Serializer.write_u8(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("u16", data, _tc) do
    {value, <<>>} = Deserializer.read_u16!(data)
    Serializer.new() |> Serializer.write_u16(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("u32", data, _tc) do
    {value, <<>>} = Deserializer.read_u32!(data)
    Serializer.new() |> Serializer.write_u32(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("u64", data, _tc) do
    {value, <<>>} = Deserializer.read_u64!(data)
    Serializer.new() |> Serializer.write_u64(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("u128", data, _tc) do
    {value, <<>>} = Deserializer.read_u128!(data)
    Serializer.new() |> Serializer.write_u128(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("i8", data, _tc) do
    {value, <<>>} = Deserializer.read_i8!(data)
    Serializer.new() |> Serializer.write_i8(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("i16", data, _tc) do
    {value, <<>>} = Deserializer.read_i16!(data)
    Serializer.new() |> Serializer.write_i16(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("i32", data, _tc) do
    {value, <<>>} = Deserializer.read_i32!(data)
    Serializer.new() |> Serializer.write_i32(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("i64", data, _tc) do
    {value, <<>>} = Deserializer.read_i64!(data)
    Serializer.new() |> Serializer.write_i64(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("i128", data, _tc) do
    {value, <<>>} = Deserializer.read_i128!(data)
    Serializer.new() |> Serializer.write_i128(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("string", data, _tc) do
    {value, <<>>} = Deserializer.read_string!(data)
    Serializer.new() |> Serializer.write_string(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("bytes", data, _tc) do
    {value, <<>>} = Deserializer.read_bytes!(data)
    Serializer.new() |> Serializer.write_bytes(value) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("fixed_bytes_32", data, _tc) do
    {value, <<>>} = Deserializer.read_fixed_bytes!(data, 32)
    Serializer.new() |> Serializer.write_fixed_bytes(value, 32) |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("option<u8>", data, _tc) do
    {has_value, rest} = Deserializer.read_bool!(data)
    ser = Serializer.new()

    ser = if has_value do
      {value, <<>>} = Deserializer.read_u8!(rest)
      ser |> Serializer.write_bool(true) |> Serializer.write_u8(value)
    else
      <<>> = rest
      ser |> Serializer.write_bool(false)
    end

    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("option<u64>", data, _tc) do
    {has_value, rest} = Deserializer.read_bool!(data)
    ser = Serializer.new()

    ser = if has_value do
      {value, <<>>} = Deserializer.read_u64!(rest)
      ser |> Serializer.write_bool(true) |> Serializer.write_u64(value)
    else
      <<>> = rest
      ser |> Serializer.write_bool(false)
    end

    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("option<bool>", data, _tc) do
    {has_value, rest} = Deserializer.read_bool!(data)
    ser = Serializer.new()

    ser = if has_value do
      {value, <<>>} = Deserializer.read_bool!(rest)
      ser |> Serializer.write_bool(true) |> Serializer.write_bool(value)
    else
      <<>> = rest
      ser |> Serializer.write_bool(false)
    end

    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("option<string>", data, _tc) do
    {has_value, rest} = Deserializer.read_bool!(data)
    ser = Serializer.new()

    ser = if has_value do
      {value, <<>>} = Deserializer.read_string!(rest)
      ser |> Serializer.write_bool(true) |> Serializer.write_string(value)
    else
      <<>> = rest
      ser |> Serializer.write_bool(false)
    end

    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("vector<u8>", data, _tc) do
    {values, <<>>} = read_vector(data, &Deserializer.read_u8!/1)
    ser = Serializer.new() |> Serializer.write_uleb128(length(values))
    ser = Enum.reduce(values, ser, fn v, s -> Serializer.write_u8(s, v) end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("vector<u64>", data, _tc) do
    {values, <<>>} = read_vector(data, &Deserializer.read_u64!/1)
    ser = Serializer.new() |> Serializer.write_uleb128(length(values))
    ser = Enum.reduce(values, ser, fn v, s -> Serializer.write_u64(s, v) end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("vector<bool>", data, _tc) do
    {values, <<>>} = read_vector(data, &Deserializer.read_bool!/1)
    ser = Serializer.new() |> Serializer.write_uleb128(length(values))
    ser = Enum.reduce(values, ser, fn v, s -> Serializer.write_bool(s, v) end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("vector<vector<u8>>", data, _tc) do
    {outer, <<>>} = read_vector(data, fn d ->
      read_vector(d, &Deserializer.read_u8!/1)
    end)

    ser = Serializer.new() |> Serializer.write_uleb128(length(outer))
    ser = Enum.reduce(outer, ser, fn inner, s ->
      s = Serializer.write_uleb128(s, length(inner))
      Enum.reduce(inner, s, fn v, s2 -> Serializer.write_u8(s2, v) end)
    end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("vector<string>", data, _tc) do
    {values, <<>>} = read_vector(data, &Deserializer.read_string!/1)
    ser = Serializer.new() |> Serializer.write_uleb128(length(values))
    ser = Enum.reduce(values, ser, fn v, s -> Serializer.write_string(s, v) end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("struct", data, tc) do
    fields = tc["value"]["fields"]
    {ser, <<>>} = Enum.reduce(fields, {Serializer.new(), data}, fn field, {s, d} ->
      case field["type"] do
        "u8" ->
          {v, rest} = Deserializer.read_u8!(d)
          {Serializer.write_u8(s, v), rest}
        "u64" ->
          {v, rest} = Deserializer.read_u64!(d)
          {Serializer.write_u64(s, v), rest}
        "string" ->
          {v, rest} = Deserializer.read_string!(d)
          {Serializer.write_string(s, v), rest}
        "fixed_bytes_32" ->
          {v, rest} = Deserializer.read_fixed_bytes!(d, 32)
          {Serializer.write_fixed_bytes(s, v, 32), rest}
      end
    end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("map<u8,u8>", data, _tc) do
    {pairs, <<>>} = read_vector(data, fn d ->
      {k, rest} = Deserializer.read_u8!(d)
      {v, rest2} = Deserializer.read_u8!(rest)
      {{k, v}, rest2}
    end)

    ser = Serializer.new() |> Serializer.write_uleb128(length(pairs))
    ser = Enum.reduce(pairs, ser, fn {k, v}, s ->
      s |> Serializer.write_u8(k) |> Serializer.write_u8(v)
    end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("map<string,u64>", data, _tc) do
    {pairs, <<>>} = read_vector(data, fn d ->
      {k, rest} = Deserializer.read_string!(d)
      {v, rest2} = Deserializer.read_u64!(rest)
      {{k, v}, rest2}
    end)

    ser = Serializer.new() |> Serializer.write_uleb128(length(pairs))
    ser = Enum.reduce(pairs, ser, fn {k, v}, s ->
      s |> Serializer.write_string(k) |> Serializer.write_u64(v)
    end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip("tuple<u8,u64>", data, _tc) do
    {a, rest} = Deserializer.read_u8!(data)
    {b, <<>>} = Deserializer.read_u64!(rest)

    Serializer.new()
    |> Serializer.write_u8(a)
    |> Serializer.write_u64(b)
    |> Serializer.to_bytes()
    |> bytes_to_hex()
  end

  defp roundtrip("vector<option<u8>>", data, _tc) do
    {values, <<>>} = read_vector(data, fn d ->
      {has_value, rest} = Deserializer.read_bool!(d)
      if has_value do
        {v, rest2} = Deserializer.read_u8!(rest)
        {{:some, v}, rest2}
      else
        {:none, rest}
      end
    end)

    ser = Serializer.new() |> Serializer.write_uleb128(length(values))
    ser = Enum.reduce(values, ser, fn
      {:some, v}, s -> s |> Serializer.write_bool(true) |> Serializer.write_u8(v)
      :none, s -> s |> Serializer.write_bool(false)
    end)
    ser |> Serializer.to_bytes() |> bytes_to_hex()
  end

  defp roundtrip(type, _data, _tc) do
    raise "Unknown type: #{type}"
  end

  defp read_vector(data, read_fn) do
    {length, rest} = Uleb128.decode!(data)
    read_n_elements(rest, length, read_fn, [])
  end

  defp read_n_elements(data, 0, _read_fn, acc), do: {Enum.reverse(acc), data}
  defp read_n_elements(data, n, read_fn, acc) do
    {value, rest} = read_fn.(data)
    read_n_elements(rest, n - 1, read_fn, [value | acc])
  end

  def run do
    input = IO.read(:stdio, :eof)
    vectors = Jason.decode!(input)

    output = %{
      "version" => vectors["version"] || "1.0.0",
      "description" => "Elixir roundtrip results",
      "primitives" => Enum.map(vectors["primitives"] || [], &process_test_case/1),
      "strings" => Enum.map(vectors["strings"] || [], &process_test_case/1),
      "bytes" => Enum.map(vectors["bytes"] || [], &process_test_case/1),
      "options" => Enum.map(vectors["options"] || [], &process_test_case/1),
      "vectors" => Enum.map(vectors["vectors"] || [], &process_test_case/1),
      "structs" => Enum.map(vectors["structs"] || [], &process_test_case/1),
      "complex" => Enum.map(vectors["complex"] || [], &process_test_case/1)
    }

    IO.puts(Jason.encode!(output, pretty: true))
  end
end

E2ERunner.run()
