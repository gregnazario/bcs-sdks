#!/usr/bin/env ruby
# Ruby BCS E2E Test Runner
#
# Reads test vectors from stdin, performs roundtrip serialization,
# and outputs results to stdout.

require 'json'

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

# Main
input = $stdin.read
vectors = JSON.parse(input)

output = {
  'version' => vectors['version'] || '1.0.0',
  'description' => 'Ruby roundtrip results',
  'primitives' => (vectors['primitives'] || []).map { |tc| process_test_case(tc) },
  'strings' => (vectors['strings'] || []).map { |tc| process_test_case(tc) },
  'bytes' => (vectors['bytes'] || []).map { |tc| process_test_case(tc) },
  'options' => (vectors['options'] || []).map { |tc| process_test_case(tc) },
  'vectors' => (vectors['vectors'] || []).map { |tc| process_test_case(tc) },
  'structs' => (vectors['structs'] || []).map { |tc| process_test_case(tc) },
  'complex' => (vectors['complex'] || []).map { |tc| process_test_case(tc) }
}

puts JSON.pretty_generate(output)
