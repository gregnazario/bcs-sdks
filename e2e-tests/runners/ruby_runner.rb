#!/usr/bin/env ruby
# Ruby BCS E2E Test Runner
#
# Reads test vectors from stdin, performs roundtrip serialization,
# and outputs results to stdout.
#
# Supports two modes:
# - Default: Roundtrip testing for correctness
# - Benchmark (--benchmark): Performance timing

require 'json'

BENCHMARK_MODE = ARGV.include?('--benchmark')

# Add the SDK to the load path
sdk_path = File.expand_path('../../sdks/ruby/lib', __dir__)
$LOAD_PATH.unshift(sdk_path) unless $LOAD_PATH.include?(sdk_path)

require 'bcs'

def hex_to_bytes(hex)
  [hex].pack('H*').force_encoding('BINARY')
end

def bytes_to_hex(bytes)
  # bytes can be an Array (from Serializer#to_bytes) or a String
  if bytes.is_a?(Array)
    bytes.pack('C*').unpack1('H*')
  else
    bytes.unpack1('H*')
  end
end

def process_test_case(test_case)
  name = test_case['name']
  type = test_case['type']
  bcs_hex = test_case['bcs_hex']

  begin
    data = hex_to_bytes(bcs_hex)
    result_hex = roundtrip(type, data, test_case)

    {
      'name' => name,
      'type' => type,
      'bcs_hex' => result_hex,
      'value' => test_case['value']
    }
  rescue => e
    {
      'name' => name,
      'type' => type,
      'bcs_hex' => '',
      'value' => test_case['value'],
      'error' => e.message
    }
  end
end

def roundtrip(type, data, test_case)
  case type
  when 'bool'
    d = BCS::Deserializer.new(data)
    value = d.read_bool
    d.check_end
    s = BCS::Serializer.new
    s.write_bool(value)
    bytes_to_hex(s.to_bytes)

  when 'u8'
    d = BCS::Deserializer.new(data)
    value = d.read_u8
    d.check_end
    s = BCS::Serializer.new
    s.write_u8(value)
    bytes_to_hex(s.to_bytes)

  when 'u16'
    d = BCS::Deserializer.new(data)
    value = d.read_u16
    d.check_end
    s = BCS::Serializer.new
    s.write_u16(value)
    bytes_to_hex(s.to_bytes)

  when 'u32'
    d = BCS::Deserializer.new(data)
    value = d.read_u32
    d.check_end
    s = BCS::Serializer.new
    s.write_u32(value)
    bytes_to_hex(s.to_bytes)

  when 'u64'
    d = BCS::Deserializer.new(data)
    value = d.read_u64
    d.check_end
    s = BCS::Serializer.new
    s.write_u64(value)
    bytes_to_hex(s.to_bytes)

  when 'u128'
    d = BCS::Deserializer.new(data)
    value = d.read_u128
    d.check_end
    s = BCS::Serializer.new
    s.write_u128(value)
    bytes_to_hex(s.to_bytes)

  when 'i8'
    d = BCS::Deserializer.new(data)
    value = d.read_i8
    d.check_end
    s = BCS::Serializer.new
    s.write_i8(value)
    bytes_to_hex(s.to_bytes)

  when 'i16'
    d = BCS::Deserializer.new(data)
    value = d.read_i16
    d.check_end
    s = BCS::Serializer.new
    s.write_i16(value)
    bytes_to_hex(s.to_bytes)

  when 'i32'
    d = BCS::Deserializer.new(data)
    value = d.read_i32
    d.check_end
    s = BCS::Serializer.new
    s.write_i32(value)
    bytes_to_hex(s.to_bytes)

  when 'i64'
    d = BCS::Deserializer.new(data)
    value = d.read_i64
    d.check_end
    s = BCS::Serializer.new
    s.write_i64(value)
    bytes_to_hex(s.to_bytes)

  when 'i128'
    d = BCS::Deserializer.new(data)
    value = d.read_i128
    d.check_end
    s = BCS::Serializer.new
    s.write_i128(value)
    bytes_to_hex(s.to_bytes)

  when 'string'
    d = BCS::Deserializer.new(data)
    value = d.read_string
    d.check_end
    s = BCS::Serializer.new
    s.write_string(value)
    bytes_to_hex(s.to_bytes)

  when 'bytes'
    d = BCS::Deserializer.new(data)
    value = d.read_bytes
    d.check_end
    s = BCS::Serializer.new
    s.write_bytes(value)
    bytes_to_hex(s.to_bytes)

  when 'fixed_bytes_32'
    d = BCS::Deserializer.new(data)
    value = d.read_fixed_bytes(32)
    d.check_end
    s = BCS::Serializer.new
    s.write_fixed_bytes(value)
    bytes_to_hex(s.to_bytes)

  when 'option<u8>'
    d = BCS::Deserializer.new(data)
    has_value = d.read_bool
    s = BCS::Serializer.new
    if has_value
      value = d.read_u8
      d.check_end
      s.write_bool(true)
      s.write_u8(value)
    else
      d.check_end
      s.write_bool(false)
    end
    bytes_to_hex(s.to_bytes)

  when 'option<u64>'
    d = BCS::Deserializer.new(data)
    has_value = d.read_bool
    s = BCS::Serializer.new
    if has_value
      value = d.read_u64
      d.check_end
      s.write_bool(true)
      s.write_u64(value)
    else
      d.check_end
      s.write_bool(false)
    end
    bytes_to_hex(s.to_bytes)

  when 'option<bool>'
    d = BCS::Deserializer.new(data)
    has_value = d.read_bool
    s = BCS::Serializer.new
    if has_value
      value = d.read_bool
      d.check_end
      s.write_bool(true)
      s.write_bool(value)
    else
      d.check_end
      s.write_bool(false)
    end
    bytes_to_hex(s.to_bytes)

  when 'option<string>'
    d = BCS::Deserializer.new(data)
    has_value = d.read_bool
    s = BCS::Serializer.new
    if has_value
      value = d.read_string
      d.check_end
      s.write_bool(true)
      s.write_string(value)
    else
      d.check_end
      s.write_bool(false)
    end
    bytes_to_hex(s.to_bytes)

  when 'vector<u8>'
    d = BCS::Deserializer.new(data)
    length = d.read_uleb128
    values = length.times.map { d.read_u8 }
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(values.length)
    values.each { |v| s.write_u8(v) }
    bytes_to_hex(s.to_bytes)

  when 'vector<u64>'
    d = BCS::Deserializer.new(data)
    length = d.read_uleb128
    values = length.times.map { d.read_u64 }
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(values.length)
    values.each { |v| s.write_u64(v) }
    bytes_to_hex(s.to_bytes)

  when 'vector<bool>'
    d = BCS::Deserializer.new(data)
    length = d.read_uleb128
    values = length.times.map { d.read_bool }
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(values.length)
    values.each { |v| s.write_bool(v) }
    bytes_to_hex(s.to_bytes)

  when 'vector<vector<u8>>'
    d = BCS::Deserializer.new(data)
    outer_len = d.read_uleb128
    outer = outer_len.times.map do
      inner_len = d.read_uleb128
      inner_len.times.map { d.read_u8 }
    end
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(outer.length)
    outer.each do |inner|
      s.write_uleb128(inner.length)
      inner.each { |v| s.write_u8(v) }
    end
    bytes_to_hex(s.to_bytes)

  when 'vector<string>'
    d = BCS::Deserializer.new(data)
    length = d.read_uleb128
    values = length.times.map { d.read_string }
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(values.length)
    values.each { |v| s.write_string(v) }
    bytes_to_hex(s.to_bytes)

  when 'struct'
    fields = test_case['value']['fields']
    d = BCS::Deserializer.new(data)
    s = BCS::Serializer.new

    fields.each do |field|
      case field['type']
      when 'u8'
        v = d.read_u8
        s.write_u8(v)
      when 'u64'
        v = d.read_u64
        s.write_u64(v)
      when 'string'
        v = d.read_string
        s.write_string(v)
      when 'fixed_bytes_32'
        v = d.read_fixed_bytes(32)
        s.write_fixed_bytes(v)
      end
    end
    d.check_end
    bytes_to_hex(s.to_bytes)

  when 'map<u8,u8>'
    d = BCS::Deserializer.new(data)
    length = d.read_uleb128
    pairs = length.times.map { [d.read_u8, d.read_u8] }
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(pairs.length)
    pairs.each { |k, v| s.write_u8(k); s.write_u8(v) }
    bytes_to_hex(s.to_bytes)

  when 'map<string,u64>'
    d = BCS::Deserializer.new(data)
    length = d.read_uleb128
    pairs = length.times.map { [d.read_string, d.read_u64] }
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(pairs.length)
    pairs.each { |k, v| s.write_string(k); s.write_u64(v) }
    bytes_to_hex(s.to_bytes)

  when 'tuple<u8,u64>'
    d = BCS::Deserializer.new(data)
    a = d.read_u8
    b = d.read_u64
    d.check_end
    s = BCS::Serializer.new
    s.write_u8(a)
    s.write_u64(b)
    bytes_to_hex(s.to_bytes)

  when 'vector<option<u8>>'
    d = BCS::Deserializer.new(data)
    length = d.read_uleb128
    values = length.times.map do
      has_value = d.read_bool
      has_value ? [:some, d.read_u8] : [:none]
    end
    d.check_end
    s = BCS::Serializer.new
    s.write_uleb128(values.length)
    values.each do |v|
      if v[0] == :some
        s.write_bool(true)
        s.write_u8(v[1])
      else
        s.write_bool(false)
      end
    end
    bytes_to_hex(s.to_bytes)

  else
    raise "Unknown type: #{type}"
  end
end

# Benchmark support
def compute_stats(times)
  return { avg: 0, min: 0, max: 0, p50: 0, p95: 0 } if times.empty?
  sorted = times.sort
  n = sorted.length
  {
    avg: times.sum.to_f / n,
    min: sorted.first,
    max: sorted.last,
    p50: sorted[n / 2],
    p95: sorted[(n * 0.95).to_i]
  }
end

def generate_value(bc)
  return bc['value'] if bc.key?('value')
  length = bc['length'] || 10
  case bc['value_generator']
  when 'repeat_char'
    (bc['char'] || 'a') * length
  when 'sequential_bytes', 'sequential_u8'
    (0...length).map { |i| i % 256 }
  when 'sequential_u64'
    (0...length).map(&:to_s)
  when 'address_bytes'
    [0] * 31 + [1]
  else
    bc['value']
  end
end

def serialize_value(s, type, value)
  case type
  when 'bool' then s.write_bool(value)
  when 'u8' then s.write_u8(value)
  when 'u16' then s.write_u16(value)
  when 'u32' then s.write_u32(value)
  when 'u64' then s.write_u64(value.to_i)
  when 'u128' then s.write_u128(value.to_i)
  when 'i8' then s.write_i8(value)
  when 'i16' then s.write_i16(value)
  when 'i32' then s.write_i32(value)
  when 'i64' then s.write_i64(value.to_i)
  when 'i128' then s.write_i128(value.to_i)
  when 'string' then s.write_string(value)
  when 'bytes' then s.write_bytes(value.pack('C*'))
  when 'fixed_bytes' then s.write_fixed_bytes(value.pack('C*'))
  when 'vector<u8>'
    s.write_uleb128(value.length)
    value.each { |v| s.write_u8(v) }
  when 'vector<u64>'
    s.write_uleb128(value.length)
    value.each { |v| s.write_u64(v.to_i) }
  when 'vector<string>'
    s.write_uleb128(value.length)
    value.each { |v| s.write_string(v) }
  else
    raise "Unknown type: #{type}"
  end
end

def deserialize_value(d, type)
  case type
  when 'bool' then d.read_bool
  when 'u8' then d.read_u8
  when 'u16' then d.read_u16
  when 'u32' then d.read_u32
  when 'u64' then d.read_u64
  when 'u128' then d.read_u128
  when 'i8' then d.read_i8
  when 'i16' then d.read_i16
  when 'i32' then d.read_i32
  when 'i64' then d.read_i64
  when 'i128' then d.read_i128
  when 'string' then d.read_string
  when 'bytes' then d.read_bytes
  when 'fixed_bytes' then d.read_fixed_bytes(32)
  when 'vector<u8>'
    length = d.read_uleb128
    length.times.map { d.read_u8 }
  when 'vector<u64>'
    length = d.read_uleb128
    length.times.map { d.read_u64 }
  when 'vector<string>'
    length = d.read_uleb128
    length.times.map { d.read_string }
  else
    raise "Unknown type: #{type}"
  end
end

def run_benchmark(spec)
  default_iterations = spec.dig('config', 'default_iterations') || 1000
  warmup = spec.dig('config', 'warmup_iterations') || 10
  results = []

  (spec['scenarios'] || {}).each do |_category, group|
    (group['benchmarks'] || []).each do |bc|
      iterations = bc['iterations'] || default_iterations
      begin
        value = generate_value(bc)
        raise "Could not generate value" if value.nil?

        # Get serialized bytes
        s = BCS::Serializer.new
        serialize_value(s, bc['type'], value)
        bcs_bytes = s.to_bytes.pack('C*')

        # Warmup serialize
        warmup.times do
          ws = BCS::Serializer.new
          serialize_value(ws, bc['type'], value)
          ws.to_bytes
        end

        # Benchmark serialize
        ser_times = iterations.times.map do
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
          bs = BCS::Serializer.new
          serialize_value(bs, bc['type'], value)
          bs.to_bytes
          Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start
        end

        # Warmup deserialize
        warmup.times do
          wd = BCS::Deserializer.new(bcs_bytes)
          deserialize_value(wd, bc['type'])
        end

        # Benchmark deserialize
        de_times = iterations.times.map do
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
          bd = BCS::Deserializer.new(bcs_bytes)
          deserialize_value(bd, bc['type'])
          Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start
        end

        ser_stats = compute_stats(ser_times)
        de_stats = compute_stats(de_times)

        results << {
          'name' => bc['name'],
          'type' => bc['type'],
          'iterations' => iterations,
          'serialize_avg_ns' => ser_stats[:avg],
          'serialize_min_ns' => ser_stats[:min],
          'serialize_max_ns' => ser_stats[:max],
          'serialize_p50_ns' => ser_stats[:p50],
          'serialize_p95_ns' => ser_stats[:p95],
          'deserialize_avg_ns' => de_stats[:avg],
          'deserialize_min_ns' => de_stats[:min],
          'deserialize_max_ns' => de_stats[:max],
          'deserialize_p50_ns' => de_stats[:p50],
          'deserialize_p95_ns' => de_stats[:p95],
          'throughput_serialize_ops_sec' => ser_stats[:avg] > 0 ? 1_000_000_000.0 / ser_stats[:avg] : 0,
          'throughput_deserialize_ops_sec' => de_stats[:avg] > 0 ? 1_000_000_000.0 / de_stats[:avg] : 0
        }
      rescue => e
        results << {
          'name' => bc['name'],
          'type' => bc['type'],
          'iterations' => iterations,
          'error' => e.message
        }
      end
    end
  end

  {
    'version' => spec['version'] || '1.0.0',
    'description' => 'Ruby benchmark results',
    'benchmarks' => results
  }
end

# Main
input = $stdin.read
data = JSON.parse(input)

if BENCHMARK_MODE
  output = run_benchmark(data)
else
  output = {
    'version' => data['version'] || '1.0.0',
    'description' => 'Ruby roundtrip results',
    'primitives' => (data['primitives'] || []).map { |tc| process_test_case(tc) },
    'strings' => (data['strings'] || []).map { |tc| process_test_case(tc) },
    'bytes' => (data['bytes'] || []).map { |tc| process_test_case(tc) },
    'options' => (data['options'] || []).map { |tc| process_test_case(tc) },
    'vectors' => (data['vectors'] || []).map { |tc| process_test_case(tc) },
    'structs' => (data['structs'] || []).map { |tc| process_test_case(tc) },
    'complex' => (data['complex'] || []).map { |tc| process_test_case(tc) }
  }
end

puts JSON.pretty_generate(output)
