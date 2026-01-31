# frozen_string_literal: true

module BCS
  # BCS Serializer - Manual serialization API
  # Optimized to use String buffer with binary encoding for better performance
  class Serializer

    # Default initial buffer capacity
    DEFAULT_CAPACITY = 256

    def initialize(capacity: DEFAULT_CAPACITY)
      @buffer = String.new(capacity: capacity, encoding: Encoding::BINARY)
      @depth = 0
    end

    # ========================================================================
    # BOOLEAN
    # ========================================================================

    # Write a boolean value
    # @param value [Boolean] The boolean to write (must be true or false, not truthy/falsy)
    # @return [Serializer] self for chaining
    # @raise [ArgumentError] if value is not a boolean
    def write_bool(value)
      case value
      when true then @buffer << BYTE_TRUE
      when false then @buffer << BYTE_FALSE
      else raise ArgumentError, "write_bool requires true or false, got #{value.class}"
      end
      self
    end

    # ========================================================================
    # UNSIGNED INTEGERS
    # ========================================================================

    # Write an unsigned 8-bit integer
    # @param value [Integer] Value in range 0..255
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_u8(value)
      raise TypeError, "u8 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("u8") unless value.between?(0, U8_MAX)

      @buffer << [value].pack("C")
      self
    end

    # Write an unsigned 16-bit integer (little-endian)
    # @param value [Integer] Value in range 0..65535
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_u16(value)
      raise TypeError, "u16 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("u16") unless value.between?(0, U16_MAX)

      @buffer << [value].pack("v")
      self
    end

    # Write an unsigned 32-bit integer (little-endian)
    # @param value [Integer] Value in range 0..2^32-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_u32(value)
      raise TypeError, "u32 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("u32") unless value.between?(0, U32_MAX)

      @buffer << [value].pack("V")
      self
    end

    # Write an unsigned 64-bit integer (little-endian)
    # @param value [Integer] Value in range 0..2^64-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_u64(value)
      raise TypeError, "u64 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("u64") unless value.between?(0, U64_MAX)

      @buffer << [value].pack("Q<")
      self
    end

    # Write an unsigned 128-bit integer (little-endian)
    # @param value [Integer] Value in range 0..2^128-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_u128(value)
      raise TypeError, "u128 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("u128") unless value.between?(0, U128_MAX)

      # Pack as two 64-bit little-endian values (low, high)
      low = value & U64_MAX
      high = value >> 64
      @buffer << [low, high].pack("Q<Q<")
      self
    end

    # Write an unsigned 256-bit integer (little-endian)
    # @param value [Integer] Value in range 0..2^256-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_u256(value)
      raise TypeError, "u256 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("u256") unless value.between?(0, U256_MAX)

      # Pack as four 64-bit little-endian values
      @buffer << [
        value & U64_MAX,
        (value >> 64) & U64_MAX,
        (value >> 128) & U64_MAX,
        (value >> 192) & U64_MAX
      ].pack("Q<Q<Q<Q<")
      self
    end

    # ========================================================================
    # SIGNED INTEGERS
    # ========================================================================

    # Write a signed 8-bit integer
    # @param value [Integer] Value in range -128..127
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_i8(value)
      raise TypeError, "i8 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("i8") unless value.between?(I8_MIN, I8_MAX)

      @buffer << [value].pack("c")
      self
    end

    # Write a signed 16-bit integer (little-endian)
    # @param value [Integer] Value in range -32768..32767
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_i16(value)
      raise TypeError, "i16 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("i16") unless value.between?(I16_MIN, I16_MAX)

      @buffer << [value].pack("s<")
      self
    end

    # Write a signed 32-bit integer (little-endian)
    # @param value [Integer] Value in range -2^31..2^31-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_i32(value)
      raise TypeError, "i32 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("i32") unless value.between?(I32_MIN, I32_MAX)

      @buffer << [value].pack("l<")
      self
    end

    # Write a signed 64-bit integer (little-endian)
    # @param value [Integer] Value in range -2^63..2^63-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_i64(value)
      raise TypeError, "i64 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("i64") unless value.between?(I64_MIN, I64_MAX)

      @buffer << [value].pack("q<")
      self
    end

    # Write a signed 128-bit integer (little-endian)
    # @param value [Integer] Value in range -2^127..2^127-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_i128(value)
      raise TypeError, "i128 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("i128") unless value.between?(I128_MIN, I128_MAX)

      unsigned = value & U128_MAX
      low = unsigned & U64_MAX
      high = unsigned >> 64
      @buffer << [low, high].pack("Q<Q<")
      self
    end

    # Write a signed 256-bit integer (little-endian)
    # @param value [Integer] Value in range -2^255..2^255-1
    # @raise [TypeError] if value is not an Integer
    # @raise [BCS::Error] if value is out of range
    def write_i256(value)
      raise TypeError, "i256 requires Integer, got #{value.class}" unless value.is_a?(Integer)
      raise Error.integer_out_of_range("i256") unless value.between?(I256_MIN, I256_MAX)

      unsigned = value & U256_MAX
      @buffer << [
        unsigned & U64_MAX,
        (unsigned >> 64) & U64_MAX,
        (unsigned >> 128) & U64_MAX,
        (unsigned >> 192) & U64_MAX
      ].pack("Q<Q<Q<Q<")
      self
    end

    # ========================================================================
    # ULEB128
    # ========================================================================

    # Write a ULEB128-encoded length
    # Optimized with inline fast path for single-byte values (0-127)
    def write_uleb128(value)
      if value < 0x80
        # Fast path: single byte for values 0-127
        @buffer << [value].pack("C")
      else
        # Slow path: multi-byte encoding
        Uleb128.encode_into(@buffer, value)
      end
      self
    end

    # ========================================================================
    # BYTES AND STRINGS
    # ========================================================================

    # Write raw bytes (without length prefix)
    def write_fixed_bytes(data)
      @buffer << if data.is_a?(String)
                   data.b
                 else
                   data.pack("C*")
                 end
      self
    end

    # Write bytes with ULEB128 length prefix
    def write_bytes(data)
      if data.is_a?(String)
        check_sequence_length(data.bytesize)
        write_uleb128(data.bytesize)
        @buffer << data.b
      else
        check_sequence_length(data.length)
        write_uleb128(data.length)
        @buffer << data.pack("C*")
      end
      self
    end

    # Write a UTF-8 string with ULEB128 length prefix
    def write_string(value)
      bytes = value.encode("UTF-8").b
      check_sequence_length(bytes.bytesize)
      write_uleb128(bytes.bytesize)
      @buffer << bytes
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
        @buffer << BYTE_FALSE
      else
        @buffer << BYTE_TRUE
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

    # ========================================================================
    # BATCH OPERATIONS (Optimized for common vector types)
    # ========================================================================

    # Write a vector of u8 values (optimized batch operation)
    # @param values [Array<Integer>, String] The array of u8 values or binary string
    # @return [Serializer] self for chaining
    def write_u8_array(values)
      if values.is_a?(String)
        check_sequence_length(values.bytesize)
        write_uleb128(values.bytesize)
        @buffer << values.b
      else
        check_sequence_length(values.length)
        write_uleb128(values.length)
        @buffer << values.pack("C*")
      end
      self
    end

    # Write a vector of u16 values (optimized batch operation)
    # @param values [Array<Integer>] The array of u16 values
    # @return [Serializer] self for chaining
    def write_u16_array(values)
      check_sequence_length(values.length)
      write_uleb128(values.length)
      @buffer << values.pack("v*")
      self
    end

    # Write a vector of u32 values (optimized batch operation)
    # @param values [Array<Integer>] The array of u32 values
    # @return [Serializer] self for chaining
    def write_u32_array(values)
      check_sequence_length(values.length)
      write_uleb128(values.length)
      @buffer << values.pack("V*")
      self
    end

    # Write a vector of u64 values (optimized batch operation)
    # @param values [Array<Integer>] The array of u64 values
    # @return [Serializer] self for chaining
    def write_u64_array(values)
      check_sequence_length(values.length)
      write_uleb128(values.length)
      @buffer << values.pack("Q<*")
      self
    end

    # Write a vector of strings (optimized batch operation)
    # @param values [Array<String>] The array of strings
    # @return [Serializer] self for chaining
    def write_string_array(values)
      check_sequence_length(values.length)
      write_uleb128(values.length)
      values.each { |v| write_string(v) }
      self
    end

    # Write a map with key/value serializers (sorted by serialized key bytes)
    # @param map [Hash] The map to serialize
    # @yield [key_ser, value_ser] Blocks to serialize keys and values
    def write_map(map, &key_serializer)
      check_sequence_length(map.size)

      # Serialize all entries and sort by key bytes
      # Reuse single serializer to reduce allocations
      temp_ser = Serializer.new(capacity: 64)
      entries = map.map do |key, value|
        temp_ser.clear
        key_serializer.call(temp_ser, key)
        [temp_ser.raw_buffer.dup, key, value] # dup because we reuse serializer
      end

      # Sort by key bytes (lexicographic binary comparison)
      entries.sort_by!(&:first)

      # Write length and entries
      write_uleb128(entries.length)
      entries.each do |key_bytes, _key, value|
        @buffer << key_bytes
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
    def enter_struct(_name = "")
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
      @buffer.bytes
    end

    # Get the serialized bytes as a binary string
    # @return [String] The serialized bytes as a binary string
    def to_binary
      @buffer.dup
    end

    # Get the current size of the buffer
    # @return [Integer] The buffer size
    def size
      @buffer.bytesize
    end

    # Alias for size
    alias length size

    # Clear the buffer for reuse
    def clear
      @buffer.clear
      @depth = 0
      self
    end

    # Get raw buffer (for internal use)
    # @return [String] The raw buffer
    def raw_buffer
      @buffer
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
