# frozen_string_literal: true

module BCS
  # BCS Deserializer - Manual deserialization API
  # Optimized to use String with binary encoding and native unpack operations
  class Deserializer

    # Pre-computed sign bit and modulus constants for signed integers
    SIGN_BIT_128 = 1 << 127
    MODULUS_128 = 1 << 128
    SIGN_BIT_256 = 1 << 255
    MODULUS_256 = 1 << 256

    def initialize(data)
      @data = data.is_a?(String) ? data.b : data.pack("C*")
      @offset = 0
      @depth = 0
    end

    # ========================================================================
    # BOOLEAN
    # ========================================================================

    # Read a boolean value
    # @return [Boolean]
    def read_bool
      byte = read_u8
      case byte
      when 0 then false
      when 1 then true
      else raise Error.invalid_boolean(byte)
      end
    end

    # ========================================================================
    # UNSIGNED INTEGERS
    # ========================================================================

    # Read an unsigned 8-bit integer
    def read_u8
      check_remaining(1)
      value = @data.getbyte(@offset)
      @offset += 1
      value
    end

    # Read an unsigned 16-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_u16
      check_remaining(2)
      value = @data.unpack1("@#{@offset}v")
      @offset += 2
      value
    end

    # Read an unsigned 32-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_u32
      check_remaining(4)
      value = @data.unpack1("@#{@offset}V")
      @offset += 4
      value
    end

    # Read an unsigned 64-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_u64
      check_remaining(8)
      value = @data.unpack1("@#{@offset}Q<")
      @offset += 8
      value
    end

    # Read an unsigned 128-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_u128
      check_remaining(16)
      low, high = @data.unpack("@#{@offset}Q<Q<")
      @offset += 16
      low | (high << 64)
    end

    # Read an unsigned 256-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_u256
      check_remaining(32)
      parts = @data.unpack("@#{@offset}Q<Q<Q<Q<")
      @offset += 32
      parts[0] | (parts[1] << 64) | (parts[2] << 128) | (parts[3] << 192)
    end

    # ========================================================================
    # SIGNED INTEGERS
    # ========================================================================

    # Read a signed 8-bit integer
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_i8
      check_remaining(1)
      value = @data.unpack1("@#{@offset}c")
      @offset += 1
      value
    end

    # Read a signed 16-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_i16
      check_remaining(2)
      value = @data.unpack1("@#{@offset}s<")
      @offset += 2
      value
    end

    # Read a signed 32-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_i32
      check_remaining(4)
      value = @data.unpack1("@#{@offset}l<")
      @offset += 4
      value
    end

    # Read a signed 64-bit integer (little-endian)
    # Optimized using unpack with offset specifier to avoid string slice allocation
    def read_i64
      check_remaining(8)
      value = @data.unpack1("@#{@offset}q<")
      @offset += 8
      value
    end

    # Read a signed 128-bit integer (little-endian)
    # Uses pre-computed constants for better performance
    def read_i128
      value = read_u128
      value >= SIGN_BIT_128 ? value - MODULUS_128 : value
    end

    # Read a signed 256-bit integer (little-endian)
    # Uses pre-computed constants for better performance
    def read_i256
      value = read_u256
      value >= SIGN_BIT_256 ? value - MODULUS_256 : value
    end

    # ========================================================================
    # ULEB128
    # ========================================================================

    # Read a ULEB128-encoded value
    # Optimized with inline fast path for single-byte values
    def read_uleb128
      check_remaining(1)
      byte = @data.getbyte(@offset)

      # Fast path: single byte (values 0-127)
      if byte < 0x80
        @offset += 1
        return byte
      end

      # Slow path: multi-byte value
      value, bytes_read = Uleb128.decode(@data, @offset)
      @offset += bytes_read
      value
    end

    # ========================================================================
    # BYTES AND STRINGS
    # ========================================================================

    # Read fixed-length bytes (without length prefix)
    # @param length [Integer] Number of bytes to read
    # @return [Array<Integer>] The bytes as an array
    def read_fixed_bytes(length)
      check_remaining(length)
      result = @data.byteslice(@offset, length).bytes
      @offset += length
      result
    end

    # Read fixed-length bytes as a binary string (without length prefix)
    # @param length [Integer] Number of bytes to read
    # @return [String] The bytes as a binary string
    def read_fixed_bytes_as_string(length)
      check_remaining(length)
      result = @data.byteslice(@offset, length)
      @offset += length
      result
    end

    # Read bytes with ULEB128 length prefix
    # @return [Array<Integer>] The bytes
    def read_bytes
      length = read_uleb128
      check_sequence_length(length)
      read_fixed_bytes(length)
    end

    # Read bytes with ULEB128 length prefix as a binary string
    # @return [String] The bytes as a binary string
    def read_bytes_as_string
      length = read_uleb128
      check_sequence_length(length)
      read_fixed_bytes_as_string(length)
    end

    # Read a UTF-8 string with ULEB128 length prefix
    # @return [String] The string
    def read_string
      str = read_bytes_as_string.force_encoding("UTF-8")
      raise Error.invalid_utf8 unless str.valid_encoding?

      str
    rescue Encoding::InvalidByteSequenceError
      raise Error.invalid_utf8
    end

    # ========================================================================
    # COMPOSITE TYPES
    # ========================================================================

    # Read an optional value
    # @yield [Deserializer] Block to deserialize the value if present
    # @return [Object, nil] The deserialized value or nil
    def read_option(&deserializer)
      tag = read_u8
      case tag
      when 0 then nil
      when 1 then deserializer.call(self)
      else raise Error.invalid_option(tag)
      end
    end

    # Read a vector with element deserializer
    # @yield [Deserializer] Block to deserialize each element
    # @return [Array] The array of deserialized values
    def read_vector(&deserializer)
      length = read_uleb128
      check_sequence_length(length)
      Array.new(length) { deserializer.call(self) }
    end

    # ========================================================================
    # BATCH OPERATIONS (Optimized for common vector types)
    # ========================================================================

    # Read a vector of u8 values (optimized batch operation)
    # @return [Array<Integer>] The array of u8 values
    def read_u8_array
      length = read_uleb128
      check_sequence_length(length)
      read_fixed_bytes(length)
    end

    # Read a vector of u8 values as a binary string (optimized batch operation)
    # @return [String] The bytes as a binary string
    def read_u8_array_as_string
      length = read_uleb128
      check_sequence_length(length)
      read_fixed_bytes_as_string(length)
    end

    # Maximum element counts for batch operations to prevent overflow
    # These ensure byte_length = length * element_size won't overflow
    MAX_U16_ARRAY_LENGTH = MAX_SEQUENCE_LENGTH / 2
    MAX_U32_ARRAY_LENGTH = MAX_SEQUENCE_LENGTH / 4
    MAX_U64_ARRAY_LENGTH = MAX_SEQUENCE_LENGTH / 8

    # Read a vector of u16 values (optimized batch operation)
    # @return [Array<Integer>] The array of u16 values
    def read_u16_array
      length = read_uleb128
      raise Error.exceeded_max_length(length) if length > MAX_U16_ARRAY_LENGTH

      byte_length = length * 2
      check_remaining(byte_length)
      result = @data.unpack("@#{@offset}v#{length}")
      @offset += byte_length
      result
    end

    # Read a vector of u32 values (optimized batch operation)
    # @return [Array<Integer>] The array of u32 values
    def read_u32_array
      length = read_uleb128
      raise Error.exceeded_max_length(length) if length > MAX_U32_ARRAY_LENGTH

      byte_length = length * 4
      check_remaining(byte_length)
      result = @data.unpack("@#{@offset}V#{length}")
      @offset += byte_length
      result
    end

    # Read a vector of u64 values (optimized batch operation)
    # @return [Array<Integer>] The array of u64 values
    def read_u64_array
      length = read_uleb128
      raise Error.exceeded_max_length(length) if length > MAX_U64_ARRAY_LENGTH

      byte_length = length * 8
      check_remaining(byte_length)
      result = @data.unpack("@#{@offset}Q<#{length}")
      @offset += byte_length
      result
    end

    # Read a vector of strings (optimized batch operation)
    # @return [Array<String>] The array of strings
    def read_string_array
      length = read_uleb128
      check_sequence_length(length)
      Array.new(length) { read_string }
    end

    # Read a map with key/value deserializers
    # @yield [key_des, value_des] Blocks to deserialize keys and values
    # @return [Hash] The deserialized map
    def read_map(&block)
      length = read_uleb128
      check_sequence_length(length)

      result = {}
      prev_key_bytes = nil

      length.times do
        # Remember position before reading key
        key_start = @offset

        key = block.call(self, :key)

        # Get key bytes for ordering check (as binary string for efficient comparison)
        key_bytes = @data.byteslice(key_start, @offset - key_start)

        # Check ordering (lexicographic comparison using native string comparison)
        if prev_key_bytes
          cmp = key_bytes <=> prev_key_bytes
          if cmp <= 0
            raise cmp.zero? ? Error.duplicate_map_key : Error.non_canonical_map
          end
        end
        prev_key_bytes = key_bytes

        value = block.call(self, :value)
        result[key] = value
      end

      result
    end

    # Read an enum variant index (ULEB128)
    def read_variant_index
      enter_container
      read_uleb128
    end

    # ========================================================================
    # CONTAINER DEPTH
    # ========================================================================

    # Enter a struct container for depth tracking
    def enter_struct(_name = "")
      enter_container
      self
    end

    # Leave the current struct container
    def leave_struct
      leave_container
      self
    end

    # Enter an enum container and read variant index
    def enter_enum
      read_variant_index
    end

    # Leave the current enum container
    def leave_enum
      leave_container
      self
    end

    # ========================================================================
    # STATE
    # ========================================================================

    # Check that all input has been consumed
    # @raise [Error] if there are remaining bytes
    def check_end
      raise Error.remaining_input(remaining) if @offset < @data.bytesize
    end

    # Get the current offset
    # @return [Integer]
    attr_reader :offset

    # Get the remaining bytes count
    # @return [Integer]
    def remaining
      @data.bytesize - @offset
    end

    # Check if there's more data to read
    # @return [Boolean]
    def remaining?
      @offset < @data.bytesize
    end

    # Get the raw data buffer (for advanced use)
    # @return [String] The raw binary data
    attr_reader :data

    private

    def check_remaining(needed)
      raise ArgumentError, "length must be non-negative" if needed < 0
      raise Error.unexpected_eof if @offset + needed > @data.bytesize
    end

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
