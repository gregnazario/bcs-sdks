# frozen_string_literal: true

module BCS
  # BCS Deserializer - Manual deserialization API
  class Deserializer
    def initialize(data)
      @data = data.is_a?(String) ? data.bytes : data.to_a
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
      value = @data[@offset]
      @offset += 1
      value
    end

    # Read an unsigned 16-bit integer (little-endian)
    def read_u16
      check_remaining(2)
      value = @data[@offset] | (@data[@offset + 1] << 8)
      @offset += 2
      value
    end

    # Read an unsigned 32-bit integer (little-endian)
    def read_u32
      check_remaining(4)
      value = 0
      4.times { |i| value |= @data[@offset + i] << (i * 8) }
      @offset += 4
      value
    end

    # Read an unsigned 64-bit integer (little-endian)
    def read_u64
      check_remaining(8)
      value = 0
      8.times { |i| value |= @data[@offset + i] << (i * 8) }
      @offset += 8
      value
    end

    # Read an unsigned 128-bit integer (little-endian)
    def read_u128
      check_remaining(16)
      value = 0
      16.times { |i| value |= @data[@offset + i] << (i * 8) }
      @offset += 16
      value
    end

    # Read an unsigned 256-bit integer (little-endian)
    def read_u256
      check_remaining(32)
      value = 0
      32.times { |i| value |= @data[@offset + i] << (i * 8) }
      @offset += 32
      value
    end

    # ========================================================================
    # SIGNED INTEGERS
    # ========================================================================

    # Read a signed 8-bit integer
    def read_i8
      value = read_u8
      value >= 0x80 ? value - 0x100 : value
    end

    # Read a signed 16-bit integer (little-endian)
    def read_i16
      value = read_u16
      value >= 0x8000 ? value - 0x10000 : value
    end

    # Read a signed 32-bit integer (little-endian)
    def read_i32
      value = read_u32
      value >= 0x80000000 ? value - 0x100000000 : value
    end

    # Read a signed 64-bit integer (little-endian)
    def read_i64
      value = read_u64
      value >= 0x8000000000000000 ? value - 0x10000000000000000 : value
    end

    # Read a signed 128-bit integer (little-endian)
    def read_i128
      value = read_u128
      value >= (1 << 127) ? value - (1 << 128) : value
    end

    # Read a signed 256-bit integer (little-endian)
    def read_i256
      value = read_u256
      value >= (1 << 255) ? value - (1 << 256) : value
    end

    # ========================================================================
    # ULEB128
    # ========================================================================

    # Read a ULEB128-encoded value
    def read_uleb128
      value, bytes_read = Uleb128.decode(@data, @offset)
      @offset += bytes_read
      value
    end

    # ========================================================================
    # BYTES AND STRINGS
    # ========================================================================

    # Read fixed-length bytes (without length prefix)
    # @param length [Integer] Number of bytes to read
    # @return [Array<Integer>] The bytes
    def read_fixed_bytes(length)
      check_remaining(length)
      result = @data[@offset, length]
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

    # Read a UTF-8 string with ULEB128 length prefix
    # @return [String] The string
    def read_string
      bytes = read_bytes
      begin
        bytes.pack("C*").force_encoding("UTF-8").tap do |str|
          raise Error.invalid_utf8 unless str.valid_encoding?
        end
      rescue Encoding::InvalidByteSequenceError
        raise Error.invalid_utf8
      end
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

        # Get key bytes for ordering check
        key_bytes = @data[key_start...@offset]

      # Check ordering (lexicographic comparison)
      if prev_key_bytes
        cmp = compare_bytes(key_bytes, prev_key_bytes)
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
      raise Error.remaining_input(remaining) if @offset < @data.length
    end

    # Get the current offset
    # @return [Integer]
    attr_reader :offset

    # Get the remaining bytes count
    # @return [Integer]
    def remaining
      @data.length - @offset
    end

    # Check if there's more data to read
    # @return [Boolean]
    def remaining?
      @offset < @data.length
    end

    private

    def check_remaining(needed)
      raise Error.unexpected_eof if @offset + needed > @data.length
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

    # Lexicographic byte comparison
    # @return [Integer] -1 if a < b, 0 if a == b, 1 if a > b
    def compare_bytes(a, b)
      min_len = [a.length, b.length].min
      min_len.times do |i|
        return -1 if a[i] < b[i]
        return 1 if a[i] > b[i]
      end
      a.length <=> b.length
    end
  end
end
