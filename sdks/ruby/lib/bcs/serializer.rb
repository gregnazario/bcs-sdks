# frozen_string_literal: true

module BCS
  # BCS Serializer - Manual serialization API
  class Serializer
    def initialize
      @buffer = []
      @depth = 0
    end

    # ========================================================================
    # BOOLEAN
    # ========================================================================

    # Write a boolean value
    # @param value [Boolean] The boolean to write
    # @return [Serializer] self for chaining
    def write_bool(value)
      @buffer << (value ? 1 : 0)
      self
    end

    # ========================================================================
    # UNSIGNED INTEGERS
    # ========================================================================

    # Write an unsigned 8-bit integer
    def write_u8(value)
      raise Error.integer_out_of_range("u8") unless value >= 0 && value <= U8_MAX

      @buffer << (value & 0xFF)
      self
    end

    # Write an unsigned 16-bit integer (little-endian)
    def write_u16(value)
      raise Error.integer_out_of_range("u16") unless value >= 0 && value <= U16_MAX

      @buffer << (value & 0xFF)
      @buffer << ((value >> 8) & 0xFF)
      self
    end

    # Write an unsigned 32-bit integer (little-endian)
    def write_u32(value)
      raise Error.integer_out_of_range("u32") unless value >= 0 && value <= U32_MAX

      4.times { |i| @buffer << ((value >> (i * 8)) & 0xFF) }
      self
    end

    # Write an unsigned 64-bit integer (little-endian)
    def write_u64(value)
      raise Error.integer_out_of_range("u64") unless value >= 0 && value <= U64_MAX

      8.times { |i| @buffer << ((value >> (i * 8)) & 0xFF) }
      self
    end

    # Write an unsigned 128-bit integer (little-endian)
    def write_u128(value)
      raise Error.integer_out_of_range("u128") unless value >= 0 && value <= U128_MAX

      16.times { |i| @buffer << ((value >> (i * 8)) & 0xFF) }
      self
    end

    # Write an unsigned 256-bit integer (little-endian)
    def write_u256(value)
      raise Error.integer_out_of_range("u256") unless value >= 0 && value <= U256_MAX

      32.times { |i| @buffer << ((value >> (i * 8)) & 0xFF) }
      self
    end

    # ========================================================================
    # SIGNED INTEGERS
    # ========================================================================

    # Write a signed 8-bit integer
    def write_i8(value)
      raise Error.integer_out_of_range("i8") unless value >= I8_MIN && value <= I8_MAX

      @buffer << (value & 0xFF)
      self
    end

    # Write a signed 16-bit integer (little-endian)
    def write_i16(value)
      raise Error.integer_out_of_range("i16") unless value >= I16_MIN && value <= I16_MAX

      unsigned = value & 0xFFFF
      @buffer << (unsigned & 0xFF)
      @buffer << ((unsigned >> 8) & 0xFF)
      self
    end

    # Write a signed 32-bit integer (little-endian)
    def write_i32(value)
      raise Error.integer_out_of_range("i32") unless value >= I32_MIN && value <= I32_MAX

      unsigned = value & 0xFFFFFFFF
      4.times { |i| @buffer << ((unsigned >> (i * 8)) & 0xFF) }
      self
    end

    # Write a signed 64-bit integer (little-endian)
    def write_i64(value)
      raise Error.integer_out_of_range("i64") unless value >= I64_MIN && value <= I64_MAX

      unsigned = value & 0xFFFFFFFFFFFFFFFF
      8.times { |i| @buffer << ((unsigned >> (i * 8)) & 0xFF) }
      self
    end

    # Write a signed 128-bit integer (little-endian)
    def write_i128(value)
      raise Error.integer_out_of_range("i128") unless value >= I128_MIN && value <= I128_MAX

      unsigned = value & ((1 << 128) - 1)
      16.times { |i| @buffer << ((unsigned >> (i * 8)) & 0xFF) }
      self
    end

    # Write a signed 256-bit integer (little-endian)
    def write_i256(value)
      raise Error.integer_out_of_range("i256") unless value >= I256_MIN && value <= I256_MAX

      unsigned = value & ((1 << 256) - 1)
      32.times { |i| @buffer << ((unsigned >> (i * 8)) & 0xFF) }
      self
    end

    # ========================================================================
    # ULEB128
    # ========================================================================

    # Write a ULEB128-encoded length
    def write_uleb128(value)
      @buffer.concat(Uleb128.encode(value))
      self
    end

    # ========================================================================
    # BYTES AND STRINGS
    # ========================================================================

    # Write raw bytes (without length prefix)
    def write_fixed_bytes(data)
      bytes = data.is_a?(String) ? data.bytes : data
      @buffer.concat(bytes)
      self
    end

    # Write bytes with ULEB128 length prefix
    def write_bytes(data)
      bytes = data.is_a?(String) ? data.bytes : data
      check_sequence_length(bytes.length)
      write_uleb128(bytes.length)
      @buffer.concat(bytes)
      self
    end

    # Write a UTF-8 string with ULEB128 length prefix
    def write_string(value)
      bytes = value.encode("UTF-8").bytes
      check_sequence_length(bytes.length)
      write_uleb128(bytes.length)
      @buffer.concat(bytes)
      self
    end

    # ========================================================================
    # COMPOSITE TYPES
    # ========================================================================

    # Write an optional value
    # @param value [Object, nil] The optional value
    # @yield [Serializer, Object] Block to serialize the value if present
    def write_option(value, &serializer)
      if value.nil?
        @buffer << 0
      else
        @buffer << 1
        serializer.call(self, value)
      end
      self
    end

    # Write a vector with element serializer
    # @param values [Array] The array of values
    # @yield [Serializer, Object] Block to serialize each element
    def write_vector(values, &serializer)
      check_sequence_length(values.length)
      write_uleb128(values.length)
      values.each { |value| serializer.call(self, value) }
      self
    end

    # Write a map with key/value serializers (sorted by serialized key bytes)
    # @param map [Hash] The map to serialize
    # @yield [key_ser, value_ser] Blocks to serialize keys and values
    def write_map(map, &key_serializer)
      check_sequence_length(map.size)

      # Serialize all entries and sort by key bytes
      entries = map.map do |key, value|
        key_ser = Serializer.new
        key_serializer.call(key_ser, key)
        [key_ser.to_bytes, key, value]
      end

      # Sort by key bytes (lexicographic)
      entries.sort_by!(&:first)

      # Write length and entries
      write_uleb128(entries.length)
      entries.each do |key_bytes, _key, value|
        @buffer.concat(key_bytes)
        yield self, value if block_given?
      end

      self
    end

    # Write an enum variant index (ULEB128)
    def write_variant_index(index)
      enter_container
      write_uleb128(index)
      self
    end

    # ========================================================================
    # CONTAINER DEPTH
    # ========================================================================

    # Enter a struct/enum container (for depth tracking)
    def enter_struct(name = "")
      enter_container
      self
    end

    # Leave the current struct container
    def leave_struct
      leave_container
      self
    end

    # Enter an enum container and write variant index
    def enter_enum(index)
      write_variant_index(index)
    end

    # Leave the current enum container
    def leave_enum
      leave_container
      self
    end

    # ========================================================================
    # OUTPUT
    # ========================================================================

    # Get the serialized bytes as an array
    # @return [Array<Integer>] The serialized bytes
    def to_bytes
      @buffer.dup
    end

    # Get the serialized bytes as a binary string
    # @return [String] The serialized bytes as a binary string
    def to_binary
      @buffer.pack("C*")
    end

    # Get the current size of the buffer
    # @return [Integer] The buffer size
    def size
      @buffer.length
    end

    # Clear the buffer
    def clear
      @buffer.clear
      @depth = 0
      self
    end

    private

    def check_sequence_length(length)
      raise Error.exceeded_max_length(length) if length > MAX_SEQUENCE_LENGTH
    end

    def enter_container
      @depth += 1
      raise Error.exceeded_container_depth(@depth) if @depth > MAX_CONTAINER_DEPTH
    end

    def leave_container
      @depth -= 1 if @depth.positive?
    end
  end
end
