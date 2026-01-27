# frozen_string_literal: true

# Copyright (c) BCS SDK Contributors
# SPDX-License-Identifier: Apache-2.0

require_relative "bcs/version"
require_relative "bcs/constants"
require_relative "bcs/errors"
require_relative "bcs/uleb128"
require_relative "bcs/serializer"
require_relative "bcs/deserializer"

# Binary Canonical Serialization (BCS) - Ruby Implementation
#
# BCS is a deterministic binary serialization format designed for
# canonical representation of data structures.
#
# @example Serialize and deserialize
#   # Serialize
#   ser = BCS::Serializer.new
#   ser.write_u64(12345)
#   ser.write_string("hello")
#   ser.write_bool(true)
#   bytes = ser.to_bytes
#
#   # Deserialize
#   des = BCS::Deserializer.new(bytes)
#   num = des.read_u64
#   str = des.read_string
#   flag = des.read_bool
#   des.check_end
#
module BCS
  class << self
    # Convenience methods for single-value serialization

    def serialize_u8(value)
      Serializer.new.write_u8(value).to_bytes
    end

    def serialize_u16(value)
      Serializer.new.write_u16(value).to_bytes
    end

    def serialize_u32(value)
      Serializer.new.write_u32(value).to_bytes
    end

    def serialize_u64(value)
      Serializer.new.write_u64(value).to_bytes
    end

    def serialize_bool(value)
      Serializer.new.write_bool(value).to_bytes
    end

    def serialize_string(value)
      Serializer.new.write_string(value).to_bytes
    end

    def serialize_bytes(value)
      Serializer.new.write_bytes(value).to_bytes
    end

    # Convenience methods for single-value deserialization

    def deserialize_u8(data)
      des = Deserializer.new(data)
      value = des.read_u8
      des.check_end
      value
    end

    def deserialize_u16(data)
      des = Deserializer.new(data)
      value = des.read_u16
      des.check_end
      value
    end

    def deserialize_u32(data)
      des = Deserializer.new(data)
      value = des.read_u32
      des.check_end
      value
    end

    def deserialize_u64(data)
      des = Deserializer.new(data)
      value = des.read_u64
      des.check_end
      value
    end

    def deserialize_bool(data)
      des = Deserializer.new(data)
      value = des.read_bool
      des.check_end
      value
    end

    def deserialize_string(data)
      des = Deserializer.new(data)
      value = des.read_string
      des.check_end
      value
    end

    def deserialize_bytes(data)
      des = Deserializer.new(data)
      value = des.read_bytes
      des.check_end
      value
    end

    # Hex utilities

    def bytes_to_hex(bytes)
      bytes.pack("C*").unpack1("H*")
    end

    def hex_to_bytes(hex)
      [hex].pack("H*").unpack("C*")
    end
  end
end
