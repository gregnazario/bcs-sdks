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

defmodule BenchmarkRunner do
  @moduledoc "Benchmark runner for Elixir BCS SDK"

  alias Bcs.{Deserializer, Serializer}

  def compute_stats(times) when length(times) == 0, do: %{avg: 0, min: 0, max: 0, p50: 0, p95: 0}
  def compute_stats(times) do
    sorted = Enum.sort(times)
    n = length(sorted)
    sum = Enum.sum(times)
    %{
      avg: sum / n,
      min: Enum.min(sorted),
      max: Enum.max(sorted),
      p50: Enum.at(sorted, div(n, 2)),
      p95: Enum.at(sorted, trunc(n * 0.95))
    }
  end

  def generate_value(bc) do
    cond do
      Map.has_key?(bc, "value") and bc["value"] != nil -> bc["value"]
      bc["value_generator"] == "repeat_char" ->
        char = bc["char"] || "a"
        length = bc["length"] || 10
        String.duplicate(char, length)
      bc["value_generator"] in ["sequential_bytes", "sequential_u8"] ->
        length = bc["length"] || 10
        Enum.map(0..(length - 1), fn i -> rem(i, 256) end)
      bc["value_generator"] == "sequential_u64" ->
        length = bc["length"] || 10
        Enum.map(0..(length - 1), &Integer.to_string/1)
      bc["value_generator"] == "address_bytes" ->
        List.duplicate(0, 31) ++ [1]
      true -> bc["value"]
    end
  end

  def serialize_value(ser, "bool", value), do: Serializer.write_bool(ser, value)
  def serialize_value(ser, "u8", value), do: Serializer.write_u8(ser, value)
  def serialize_value(ser, "u16", value), do: Serializer.write_u16(ser, value)
  def serialize_value(ser, "u32", value), do: Serializer.write_u32(ser, value)
  def serialize_value(ser, "u64", value) do
    v = if is_binary(value), do: String.to_integer(value), else: value
    Serializer.write_u64(ser, v)
  end
  def serialize_value(ser, "u128", value) do
    v = if is_binary(value), do: String.to_integer(value), else: value
    Serializer.write_u128(ser, v)
  end
  def serialize_value(ser, "i8", value), do: Serializer.write_i8(ser, value)
  def serialize_value(ser, "i16", value), do: Serializer.write_i16(ser, value)
  def serialize_value(ser, "i32", value), do: Serializer.write_i32(ser, value)
  def serialize_value(ser, "i64", value) do
    v = if is_binary(value), do: String.to_integer(value), else: value
    Serializer.write_i64(ser, v)
  end
  def serialize_value(ser, "i128", value) do
    v = if is_binary(value), do: String.to_integer(value), else: value
    Serializer.write_i128(ser, v)
  end
  def serialize_value(ser, "string", value), do: Serializer.write_string(ser, value)
  def serialize_value(ser, "bytes", value) when is_list(value), do: Serializer.write_bytes(ser, :binary.list_to_bin(value))
  def serialize_value(ser, "bytes", value), do: Serializer.write_bytes(ser, value)
  def serialize_value(ser, "fixed_bytes", value) when is_list(value), do: Serializer.write_fixed_bytes(ser, :binary.list_to_bin(value), length(value))
  def serialize_value(ser, "vector<u8>", value) do
    ser = Serializer.write_uleb128(ser, length(value))
    Enum.reduce(value, ser, fn v, s -> Serializer.write_u8(s, v) end)
  end
  def serialize_value(ser, "vector<u64>", value) do
    ser = Serializer.write_uleb128(ser, length(value))
    Enum.reduce(value, ser, fn v, s ->
      val = if is_binary(v), do: String.to_integer(v), else: v
      Serializer.write_u64(s, val)
    end)
  end
  def serialize_value(ser, "vector<string>", value) do
    ser = Serializer.write_uleb128(ser, length(value))
    Enum.reduce(value, ser, fn v, s -> Serializer.write_string(s, v) end)
  end
  def serialize_value(ser, _type, _value), do: ser

  def deserialize_value(data, "bool"), do: Deserializer.read_bool!(data)
  def deserialize_value(data, "u8"), do: Deserializer.read_u8!(data)
  def deserialize_value(data, "u16"), do: Deserializer.read_u16!(data)
  def deserialize_value(data, "u32"), do: Deserializer.read_u32!(data)
  def deserialize_value(data, "u64"), do: Deserializer.read_u64!(data)
  def deserialize_value(data, "u128"), do: Deserializer.read_u128!(data)
  def deserialize_value(data, "i8"), do: Deserializer.read_i8!(data)
  def deserialize_value(data, "i16"), do: Deserializer.read_i16!(data)
  def deserialize_value(data, "i32"), do: Deserializer.read_i32!(data)
  def deserialize_value(data, "i64"), do: Deserializer.read_i64!(data)
  def deserialize_value(data, "i128"), do: Deserializer.read_i128!(data)
  def deserialize_value(data, "string"), do: Deserializer.read_string!(data)
  def deserialize_value(data, "bytes"), do: Deserializer.read_bytes!(data)
  def deserialize_value(data, "fixed_bytes"), do: Deserializer.read_fixed_bytes!(data, 32)
  def deserialize_value(data, "vector<u8>") do
    {len, rest} = Bcs.Uleb128.decode!(data)
    Enum.reduce(1..len, {[], rest}, fn _, {acc, d} ->
      {v, r} = Deserializer.read_u8!(d)
      {acc ++ [v], r}
    end)
  end
  def deserialize_value(data, "vector<u64>") do
    {len, rest} = Bcs.Uleb128.decode!(data)
    Enum.reduce(1..len, {[], rest}, fn _, {acc, d} ->
      {v, r} = Deserializer.read_u64!(d)
      {acc ++ [v], r}
    end)
  end
  def deserialize_value(data, "vector<string>") do
    {len, rest} = Bcs.Uleb128.decode!(data)
    Enum.reduce(1..len, {[], rest}, fn _, {acc, d} ->
      {v, r} = Deserializer.read_string!(d)
      {acc ++ [v], r}
    end)
  end
  def deserialize_value(data, _type), do: {nil, data}

  def run_benchmark(spec) do
    default_iterations = get_in(spec, ["config", "default_iterations"]) || 1000
    warmup = get_in(spec, ["config", "warmup_iterations"]) || 10

    scenarios = spec["scenarios"] || %{}

    results = Enum.flat_map(scenarios, fn {_category, group} ->
      benchmarks = group["benchmarks"] || []
      Enum.map(benchmarks, fn bc ->
        iterations = bc["iterations"] || default_iterations
        run_single_benchmark(bc, iterations, warmup)
      end)
    end)

    %{
      "version" => spec["version"] || "1.0.0",
      "description" => "Elixir benchmark results",
      "benchmarks" => results
    }
  end

  defp run_single_benchmark(bc, iterations, warmup) do
    try do
      value = generate_value(bc)
      type = bc["type"]

      # Serialize to get bytes
      ser = Serializer.new() |> serialize_value(type, value)
      bcs_bytes = Serializer.to_bytes(ser)

      # Warmup serialize
      for _ <- 1..warmup do
        Serializer.new() |> serialize_value(type, value) |> Serializer.to_bytes()
      end

      # Benchmark serialize
      ser_times = for _ <- 1..iterations do
        start = :erlang.monotonic_time(:nanosecond)
        Serializer.new() |> serialize_value(type, value) |> Serializer.to_bytes()
        :erlang.monotonic_time(:nanosecond) - start
      end

      # Warmup deserialize
      for _ <- 1..warmup do
        deserialize_value(bcs_bytes, type)
      end

      # Benchmark deserialize
      de_times = for _ <- 1..iterations do
        start = :erlang.monotonic_time(:nanosecond)
        deserialize_value(bcs_bytes, type)
        :erlang.monotonic_time(:nanosecond) - start
      end

      ser_stats = compute_stats(ser_times)
      de_stats = compute_stats(de_times)

      ser_throughput = if ser_stats.avg > 0, do: 1_000_000_000 / ser_stats.avg, else: 0
      de_throughput = if de_stats.avg > 0, do: 1_000_000_000 / de_stats.avg, else: 0

      %{
        "name" => bc["name"],
        "type" => type,
        "iterations" => iterations,
        "serialize_avg_ns" => ser_stats.avg,
        "serialize_min_ns" => ser_stats.min,
        "serialize_max_ns" => ser_stats.max,
        "serialize_p50_ns" => ser_stats.p50,
        "serialize_p95_ns" => ser_stats.p95,
        "deserialize_avg_ns" => de_stats.avg,
        "deserialize_min_ns" => de_stats.min,
        "deserialize_max_ns" => de_stats.max,
        "deserialize_p50_ns" => de_stats.p50,
        "deserialize_p95_ns" => de_stats.p95,
        "throughput_serialize_ops_sec" => ser_throughput,
        "throughput_deserialize_ops_sec" => de_throughput
      }
    rescue
      e ->
        %{
          "name" => bc["name"],
          "type" => bc["type"],
          "iterations" => iterations,
          "error" => Exception.message(e)
        }
    end
  end
end

if "--benchmark" in System.argv() do
  input = IO.read(:stdio, :eof)
  spec = Jason.decode!(input)
  output = BenchmarkRunner.run_benchmark(spec)
  IO.puts(Jason.encode!(output, pretty: true))
else
  E2ERunner.run()
end
