# frozen_string_literal: true

require "minitest/autorun"
require "json"
require_relative "../lib/bcs"

class BCSTest < Minitest::Test

  # ============================================================================
  # ULEB128 Tests
  # ============================================================================

  def test_uleb128_encode
    assert_equal [0x00], BCS::Uleb128.encode(0)
    assert_equal [0x01], BCS::Uleb128.encode(1)
    assert_equal [0x7f], BCS::Uleb128.encode(127)
    assert_equal [0x80, 0x01], BCS::Uleb128.encode(128)
    assert_equal [0xff, 0x01], BCS::Uleb128.encode(255)
    assert_equal [0xac, 0x02], BCS::Uleb128.encode(300)
    assert_equal [0x80, 0x80, 0x01], BCS::Uleb128.encode(16_384)
    assert_equal [0xff, 0xff, 0xff, 0xff, 0x0f], BCS::Uleb128.encode(0xFFFFFFFF)
  end

  def test_uleb128_decode
    assert_equal [0, 1], BCS::Uleb128.decode([0x00])
    assert_equal [127, 1], BCS::Uleb128.decode([0x7f])
    assert_equal [128, 2], BCS::Uleb128.decode([0x80, 0x01])
    assert_equal [0xFFFFFFFF, 5], BCS::Uleb128.decode([0xff, 0xff, 0xff, 0xff, 0x0f])
  end

  def test_uleb128_reject_non_canonical
    error = assert_raises(BCS::Error) { BCS::Uleb128.decode([0x80, 0x00]) }
    assert_equal :non_canonical_uleb128, error.type
  end

  def test_uleb128_reject_overflow
    error = assert_raises(BCS::Error) { BCS::Uleb128.decode([0xff, 0xff, 0xff, 0xff, 0x1f]) }
    assert_equal :uleb128_overflow, error.type
  end

  # ============================================================================
  # Boolean Tests
  # ============================================================================

  def test_bool_serialization
    assert_equal [0x01], BCS.serialize_bool(true)
    assert_equal [0x00], BCS.serialize_bool(false)
  end

  def test_bool_deserialization
    assert_equal true, BCS.deserialize_bool([0x01])
    assert_equal false, BCS.deserialize_bool([0x00])
  end

  def test_bool_invalid_value
    error = assert_raises(BCS::Error) { BCS.deserialize_bool([0x02]) }
    assert_equal :invalid_boolean, error.type
  end

  # ============================================================================
  # Integer Tests
  # ============================================================================

  def test_u8_serialization
    assert_equal [0x00], BCS.serialize_u8(0)
    assert_equal [0xff], BCS.serialize_u8(255)
    assert_equal [0x2a], BCS.serialize_u8(42)
  end

  def test_u16_serialization
    assert_equal [0x00, 0x00], BCS.serialize_u16(0)
    assert_equal [0x34, 0x12], BCS.serialize_u16(0x1234)
    assert_equal [0xff, 0xff], BCS.serialize_u16(0xFFFF)
  end

  def test_u32_serialization
    assert_equal [0x00, 0x00, 0x00, 0x00], BCS.serialize_u32(0)
    assert_equal [0x78, 0x56, 0x34, 0x12], BCS.serialize_u32(0x12345678)
  end

  def test_u64_serialization
    assert_equal [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], BCS.serialize_u64(0)
    assert_equal [0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12],
                 BCS.serialize_u64(0x123456789ABCDEF0)
  end

  def test_i8_serialization
    ser = BCS::Serializer.new
    ser.write_i8(-1)
    assert_equal [0xff], ser.to_bytes

    ser.clear.write_i8(-128)
    assert_equal [0x80], ser.to_bytes

    ser.clear.write_i8(127)
    assert_equal [0x7f], ser.to_bytes
  end

  def test_i16_serialization
    ser = BCS::Serializer.new
    ser.write_i16(-1)
    assert_equal [0xff, 0xff], ser.to_bytes

    ser.clear.write_i16(-32_768)
    assert_equal [0x00, 0x80], ser.to_bytes
  end

  def test_i32_serialization
    ser = BCS::Serializer.new
    ser.write_i32(-1)
    assert_equal [0xff, 0xff, 0xff, 0xff], ser.to_bytes

    ser.clear.write_i32(2_147_483_647) # max
    assert_equal [0xff, 0xff, 0xff, 0x7f], ser.to_bytes

    ser.clear.write_i32(-2_147_483_648) # min
    assert_equal [0x00, 0x00, 0x00, 0x80], ser.to_bytes
  end

  def test_i64_serialization
    ser = BCS::Serializer.new
    ser.write_i64(-1)
    assert_equal [0xff] * 8, ser.to_bytes

    ser.clear.write_i64(9_223_372_036_854_775_807) # max
    assert_equal [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f], ser.to_bytes

    ser.clear.write_i64(-9_223_372_036_854_775_808) # min
    assert_equal [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80], ser.to_bytes
  end

  def test_i128_serialization
    ser = BCS::Serializer.new
    ser.write_i128(-1)
    bytes = ser.to_bytes
    assert_equal 16, bytes.length
    bytes.each { |b| assert_equal 0xff, b }
  end

  def test_i32_deserialization
    des = BCS::Deserializer.new([0xff, 0xff, 0xff, 0xff])
    assert_equal(-1, des.read_i32)

    des = BCS::Deserializer.new([0x00, 0x00, 0x00, 0x80])
    assert_equal(-2_147_483_648, des.read_i32)
  end

  def test_i64_deserialization
    des = BCS::Deserializer.new([0xff] * 8)
    assert_equal(-1, des.read_i64)

    des = BCS::Deserializer.new([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80])
    assert_equal(-9_223_372_036_854_775_808, des.read_i64)
  end

  def test_i128_deserialization
    des = BCS::Deserializer.new([0xff] * 16)
    assert_equal(-1, des.read_i128)
  end

  def test_integer_deserialization
    assert_equal 42, BCS.deserialize_u8([0x2a])
    assert_equal 0x1234, BCS.deserialize_u16([0x34, 0x12])
    assert_equal 0x12345678, BCS.deserialize_u32([0x78, 0x56, 0x34, 0x12])
    assert_equal 0x123456789ABCDEF0, BCS.deserialize_u64([0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12])
  end

  def test_signed_integer_deserialization
    des = BCS::Deserializer.new([0xff])
    assert_equal(-1, des.read_i8)

    des = BCS::Deserializer.new([0x00, 0x80])
    assert_equal(-32_768, des.read_i16)
  end

  # ============================================================================
  # u128/u256 Tests
  # ============================================================================

  def test_u128_serialization
    ser = BCS::Serializer.new
    ser.write_u128(1)
    bytes = ser.to_bytes
    assert_equal 16, bytes.length
    assert_equal 0x01, bytes[0]
    bytes[1..].each { |b| assert_equal 0, b }
  end

  def test_u256_serialization
    ser = BCS::Serializer.new
    value = (1 << 255) + 0xff
    ser.write_u256(value)
    bytes = ser.to_bytes
    assert_equal 32, bytes.length
    assert_equal 0xff, bytes[0]
    assert_equal 0x80, bytes[31]
  end

  # ============================================================================
  # String Tests
  # ============================================================================

  def test_string_serialization
    assert_equal [0x00], BCS.serialize_string("")
    assert_equal [0x05, 0x68, 0x65, 0x6c, 0x6c, 0x6f], BCS.serialize_string("hello")
  end

  def test_string_deserialization
    assert_equal "", BCS.deserialize_string([0x00])
    assert_equal "hello", BCS.deserialize_string([0x05, 0x68, 0x65, 0x6c, 0x6c, 0x6f])
  end

  def test_invalid_utf8
    error = assert_raises(BCS::Error) { BCS.deserialize_string([0x02, 0xff, 0xfe]) }
    assert_equal :invalid_utf8, error.type
  end

  # ============================================================================
  # Bytes Tests
  # ============================================================================

  def test_bytes_serialization
    bytes = BCS.serialize_bytes([0x01, 0x02, 0x03])
    assert_equal [0x03, 0x01, 0x02, 0x03], bytes
  end

  def test_bytes_deserialization
    bytes = BCS.deserialize_bytes([0x03, 0x01, 0x02, 0x03])
    assert_equal [0x01, 0x02, 0x03], bytes
  end

  # ============================================================================
  # Option Tests
  # ============================================================================

  def test_option_some_serialization
    ser = BCS::Serializer.new
    ser.write_option(42) { |s, v| s.write_u8(v) }
    assert_equal [0x01, 0x2a], ser.to_bytes
  end

  def test_option_none_serialization
    ser = BCS::Serializer.new
    ser.write_option(nil) { |s, v| s.write_u8(v) }
    assert_equal [0x00], ser.to_bytes
  end

  def test_option_some_deserialization
    des = BCS::Deserializer.new([0x01, 0x2a])
    opt = des.read_option(&:read_u8)
    assert_equal 42, opt
  end

  def test_option_none_deserialization
    des = BCS::Deserializer.new([0x00])
    opt = des.read_option(&:read_u8)
    assert_nil opt
  end

  def test_option_invalid_tag
    des = BCS::Deserializer.new([0x02])
    error = assert_raises(BCS::Error) { des.read_option(&:read_u8) }
    assert_equal :invalid_option, error.type
  end

  # ============================================================================
  # Vector Tests
  # ============================================================================

  def test_vector_empty_serialization
    ser = BCS::Serializer.new
    ser.write_vector([]) { |s, v| s.write_u8(v) }
    assert_equal [0x00], ser.to_bytes
  end

  def test_vector_u8_serialization
    ser = BCS::Serializer.new
    ser.write_vector([1, 2, 3]) { |s, v| s.write_u8(v) }
    assert_equal [0x03, 0x01, 0x02, 0x03], ser.to_bytes
  end

  def test_vector_u16_serialization
    ser = BCS::Serializer.new
    ser.write_vector([1, 2, 3]) { |s, v| s.write_u16(v) }
    assert_equal [0x03, 0x01, 0x00, 0x02, 0x00, 0x03, 0x00], ser.to_bytes
  end

  def test_vector_deserialization
    des = BCS::Deserializer.new([0x03, 0x01, 0x02, 0x03])
    vec = des.read_vector(&:read_u8)
    assert_equal [1, 2, 3], vec
  end

  # ============================================================================
  # Map Tests
  # ============================================================================

  def test_map_serialization
    ser = BCS::Serializer.new
    map = { 1 => 10, 2 => 20, 3 => 30 }
    ser.write_map(map) { |s, k| s.write_u8(k) }
    # NOTE: we need to write values separately in this simple implementation

    # For a complete map serialization, we'd need both key and value serializers
    # This test just verifies the basic structure
  end

  def test_map_deserialization
    # 3 entries: (1, 10), (2, 20), (3, 30)
    des = BCS::Deserializer.new([0x03, 0x01, 0x0a, 0x02, 0x14, 0x03, 0x1e])
    map = des.read_map do |d, type|
      case type
      when :key then d.read_u8
      when :value then d.read_u8
      end
    end

    assert_equal 3, map.size
    assert_equal 10, map[1]
    assert_equal 20, map[2]
    assert_equal 30, map[3]
  end

  def test_map_non_canonical_order
    # Keys out of order: 2, 1
    des = BCS::Deserializer.new([0x02, 0x02, 0x14, 0x01, 0x0a])
    error = assert_raises(BCS::Error) do
      des.read_map do |d, type|
        case type
        when :key then d.read_u8
        when :value then d.read_u8
        end
      end
    end
    assert_equal :non_canonical_map, error.type
  end

  def test_map_duplicate_keys
    # Duplicate key: 1, 1
    des = BCS::Deserializer.new([0x02, 0x01, 0x0a, 0x01, 0x14])
    error = assert_raises(BCS::Error) do
      des.read_map do |d, type|
        case type
        when :key then d.read_u8
        when :value then d.read_u8
        end
      end
    end
    assert_equal :duplicate_map_key, error.type
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  def test_unexpected_eof
    des = BCS::Deserializer.new([0x01]) # Only 1 byte, need 2 for u16
    error = assert_raises(BCS::Error) { des.read_u16 }
    assert_equal :unexpected_eof, error.type
  end

  def test_remaining_input
    des = BCS::Deserializer.new([0x01, 0x02]) # Extra byte
    des.read_u8
    error = assert_raises(BCS::Error) { des.check_end }
    assert_equal :remaining_input, error.type
  end

  # ============================================================================
  # Round-trip Tests
  # ============================================================================

  def test_round_trip_u64
    original = 0x123456789ABCDEF0
    bytes = BCS.serialize_u64(original)
    result = BCS.deserialize_u64(bytes)
    assert_equal original, result
  end

  def test_round_trip_string
    original = "Hello, BCS! 你好世界"
    bytes = BCS.serialize_string(original)
    result = BCS.deserialize_string(bytes)
    assert_equal original, result
  end

  def test_round_trip_complex
    # Serialize: (u8, string, vector<u16>)
    ser = BCS::Serializer.new
    ser.write_u8(42)
    ser.write_string("test")
    ser.write_vector([100, 200, 300]) { |s, v| s.write_u16(v) }
    bytes = ser.to_bytes

    # Deserialize
    des = BCS::Deserializer.new(bytes)
    assert_equal 42, des.read_u8
    assert_equal "test", des.read_string
    vec = des.read_vector(&:read_u16)
    assert_equal [100, 200, 300], vec
    des.check_end
  end

  # ============================================================================
  # Hex Utilities
  # ============================================================================

  def test_bytes_to_hex
    assert_equal "0102abcd", BCS.bytes_to_hex([0x01, 0x02, 0xab, 0xcd])
  end

  def test_hex_to_bytes
    assert_equal [0x01, 0x02, 0xab, 0xcd], BCS.hex_to_bytes("0102abcd")
  end

  # ============================================================================
  # Batch Operations Tests
  # ============================================================================

  def test_u8_array_round_trip
    values = (0..255).to_a
    ser = BCS::Serializer.new
    ser.write_u8_array(values)
    bytes = ser.to_bytes

    des = BCS::Deserializer.new(bytes)
    result = des.read_u8_array
    assert_equal values, result
  end

  def test_u64_array_round_trip
    values = [0, 100, 0xFFFFFFFFFFFFFFFF, 12_345, 999_999_999]
    ser = BCS::Serializer.new
    ser.write_u64_array(values)
    bytes = ser.to_bytes

    des = BCS::Deserializer.new(bytes)
    result = des.read_u64_array
    assert_equal values, result
  end

  def test_string_array_round_trip
    values = ["hello", "world", "", "BCS", "你好"]
    ser = BCS::Serializer.new
    ser.write_string_array(values)
    bytes = ser.to_bytes

    des = BCS::Deserializer.new(bytes)
    result = des.read_string_array
    assert_equal values, result
  end

  # ============================================================================
  # Object Pool Tests
  # ============================================================================

  def test_serializer_pool
    # Acquire and use
    ser = BCS.acquire_serializer
    ser.write_u64(12_345)
    bytes1 = ser.to_bytes
    BCS.release_serializer(ser)

    # Acquire again (should get the same instance from pool)
    ser2 = BCS.acquire_serializer
    assert_equal 0, ser2.size # Should be cleared
    ser2.write_u64(67_890)
    bytes2 = ser2.to_bytes
    BCS.release_serializer(ser2)

    # Verify both serializations worked
    assert_equal 12_345, BCS.deserialize_u64(bytes1)
    assert_equal 67_890, BCS.deserialize_u64(bytes2)
  end

  def test_with_serializer_block
    bytes = BCS.with_serializer do |ser|
      ser.write_u64(99_999)
      ser.to_bytes
    end
    assert_equal 99_999, BCS.deserialize_u64(bytes)
  end

end
