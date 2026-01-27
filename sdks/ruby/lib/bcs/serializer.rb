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
    # @param value [Boolean] The boolean to write
    # @return [Serializer] self for chaining
    def write_bool(value)
      @buffer << (value ? "\x01" : "\x00")
      self
    end

    # ========================================================================
    # UNSIGNED INTEGERS
    # ========================================================================

    # Write an unsigned 8-bit integer
    def write_u8(value)
      raise Error.integer_out_of_range("u8") unless value >= 0 && value <= U8_MAX

      @buffer << [value].pack("C")
      self
    end

    # Write an unsigned 16-bit integer (little-endian)
    def write_u16(value)
      raise Error.integer_out_of_range("u16") unless value >= 0 && value <= U16_MAX

      @buffer << [value].pack("v")
      self
    end

    # Write an unsigned 32-bit integer (little-endian)
    def write_u32(value)
      raise Error.integer_out_of_range("u32") unless value >= 0 && value <= U32_MAX

      @buffer << [value].pack("V")
      self
    end

    # Write an unsigned 64-bit integer (little-endian)
    def write_u64(value)
      raise Error.integer_out_of_range("u64") unless value >= 0 && value <= U64_MAX

      @buffer << [value].pack("Q<")
      self
    end

    # Write an unsigned 128-bit integer (little-endian)
    def write_u128(value)
      raise Error.integer_out_of_range("u128") unless value >= 0 && value <= U128_MAX

      # Pack as two 64-bit little-endian values (low, high)
      low = value & U64_MAX
      high = value >> 64
      @buffer << [low, high].pack("Q<Q<")
      self
    end

    # Write an unsigned 256-bit integer (little-endian)
    def write_u256(value)
      raise Error.integer_out_of_range("u256") unless value >= 0 && value <= U256_MAX

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
    def write_i8(value)
      raise Error.integer_out_of_range("i8") unless value >= I8_MIN && value <= I8_MAX

      @buffer << [value].pack("c")
      self
    end

    # Write a signed 16-bit integer (little-endian)
    def write_i16(value)
      raise Error.integer_out_of_range("i16") unless value >= I16_MIN && value <= I16_MAX

      @buffer << [value].pack("s<")
      self
    end

    # Write a signed 32-bit integer (little-endian)
    def write_i32(value)
      raise Error.integer_out_of_range("i32") unless value >= I32_MIN && value <= I32_MAX

      @buffer << [value].pack("l<")
      self
    end

    # Write a signed 64-bit integer (little-endian)
    def write_i64(value)
      raise Error.integer_out_of_range("i64") unless value >= I64_MIN && value <= I64_MAX

      @buffer << [value].pack("q<")
      self
    end

    # Write a signed 128-bit integer (little-endian)
    def write_i128(value)
      raise Error.integer_out_of_range("i128") unless value >= I128_MIN && value <= I128_MAX

      unsigned = value & U128_MAX
      low = unsigned & U64_MAX
      high = unsigned >> 64
      @buffer << [low, high].pack("Q<Q<")
      self
    end

    # Write a signed 256-bit integer (little-endian)
    def write_i256(value)
      raise Error.integer_out_of_range("i256") unless value >= I256_MIN && value <= I256_MAX

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
      if data.is_a?(String)
        @buffer << data.b
      else
        @buffer << data.pack("C*")
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
      entries = map.map do |key, value|
        key_ser = Serializer.new(capacity: 64)
        key_serializer.call(key_ser, key)
        [key_ser.raw_buffer, key, value]
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
