# frozen_string_literal: true

module BCS
  # ULEB128 encoding/decoding utilities
  # Optimized for both array and string buffer output
  module Uleb128
    # Maximum value that can be encoded as ULEB128 in BCS (u32 max)
    MAX_VALUE = 0xFFFFFFFF

    # Maximum number of bytes in a ULEB128-encoded u32
    MAX_BYTES = 5

    class << self

      # Encode a 32-bit unsigned integer as ULEB128
      # @param value [Integer] The value to encode
      # @return [Array<Integer>] Array of bytes containing the ULEB128 encoding
      def encode(value)
        raise Error.integer_out_of_range("uleb128") if value.negative? || value > MAX_VALUE

        # Fast path for single-byte values
        return [value] if value < 0x80

        result = []
        loop do
          byte = value & 0x7F
          value >>= 7
          byte |= 0x80 if value != 0
          result << byte
          break if value.zero?
        end
        result
      end

      # Encode a 32-bit unsigned integer as ULEB128 directly into a String buffer
      # Optimized to avoid intermediate array allocations
      # @param buffer [String] The buffer to append to
      # @param value [Integer] The value to encode
      # @return [String] The buffer (for chaining)
      def encode_into(buffer, value)
        raise Error.integer_out_of_range("uleb128") if value.negative? || value > MAX_VALUE

        # Optimized paths for common value ranges (1-4 bytes)
        if value < 0x4000 # 2 bytes max
          if value < 0x80
            buffer << value.chr(Encoding::BINARY)
          else
            buffer << ((value & 0x7F) | 0x80).chr(Encoding::BINARY)
            buffer << (value >> 7).chr(Encoding::BINARY)
          end
        elsif value < 0x200000 # 3 bytes
          buffer << ((value & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (((value >> 7) & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (value >> 14).chr(Encoding::BINARY)
        elsif value < 0x10000000 # 4 bytes
          buffer << ((value & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (((value >> 7) & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (((value >> 14) & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (value >> 21).chr(Encoding::BINARY)
        else # 5 bytes (max for u32)
          buffer << ((value & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (((value >> 7) & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (((value >> 14) & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (((value >> 21) & 0x7F) | 0x80).chr(Encoding::BINARY)
          buffer << (value >> 28).chr(Encoding::BINARY)
        end
        buffer
      end

      # Decode a ULEB128-encoded value from bytes (array or string)
      # @param data [Array<Integer>, String] The data to decode from
      # @param offset [Integer] Starting offset in the data
      # @return [Array<Integer>] Tuple of [decoded value, number of bytes consumed]
      # @raise [Error] on invalid encoding or overflow
      def decode(data, offset = 0)
        value = 0
        shift = 0
        bytes_read = 0
        data_length = data.is_a?(String) ? data.bytesize : data.length

        MAX_BYTES.times do |i|
          raise Error.unexpected_eof if offset + i >= data_length

          byte = data.is_a?(String) ? data.getbyte(offset + i) : data[offset + i]
          digit = byte & 0x7F

          value |= digit << shift
          bytes_read = i + 1

          # Check if this is the last byte (high bit not set)
          if (byte & 0x80).zero?
            # Check for non-canonical encoding (trailing zeros)
            raise Error.non_canonical_uleb128 if shift.positive? && digit.zero?

            # Check for overflow
            raise Error.uleb128_overflow if value > MAX_VALUE

            return [value, bytes_read]
          end

          shift += 7
        end

        # If we've read MAX_BYTES and still have continuation bit, overflow
        raise Error.uleb128_overflow
      end

      # Decode ULEB128 with fast path for single-byte values
      # @param data [String] The data string to decode from
      # @param offset [Integer] Starting offset in the data
      # @return [Array<Integer>] Tuple of [decoded value, number of bytes consumed]
      def decode_fast(data, offset = 0)
        raise Error.unexpected_eof if offset >= data.bytesize

        byte = data.getbyte(offset)
        # Fast path: single-byte value (0-127)
        return [byte, 1] if byte < 0x80

        # Slow path: multi-byte value
        decode(data, offset)
      end

      # Calculate the encoded size of a value
      # @param value [Integer] The value to calculate size for
      # @return [Integer] Number of bytes required to encode the value
      def encoded_size(value)
        return 1 if value < 0x80
        return 2 if value < 0x4000
        return 3 if value < 0x200000
        return 4 if value < 0x10000000

        5
      end

    end
  end
end
