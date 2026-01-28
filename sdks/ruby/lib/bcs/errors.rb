# frozen_string_literal: true

module BCS
  # Base class for all BCS errors
  class Error < StandardError

    attr_reader :type

    def initialize(type, message)
      @type = type
      super(message)
    end

  end

  # Error types
  module ErrorType
    UNEXPECTED_EOF = :unexpected_eof
    INVALID_BOOLEAN = :invalid_boolean
    NON_CANONICAL_ULEB128 = :non_canonical_uleb128
    ULEB128_OVERFLOW = :uleb128_overflow
    EXCEEDED_MAX_LENGTH = :exceeded_max_length
    EXCEEDED_CONTAINER_DEPTH = :exceeded_container_depth
    INVALID_UTF8 = :invalid_utf8
    NON_CANONICAL_MAP = :non_canonical_map
    DUPLICATE_MAP_KEY = :duplicate_map_key
    INTEGER_OUT_OF_RANGE = :integer_out_of_range
    REMAINING_INPUT = :remaining_input
    INVALID_OPTION = :invalid_option
  end

  # Factory methods for errors
  class << Error

    def unexpected_eof
      new(ErrorType::UNEXPECTED_EOF, "Unexpected end of input")
    end

    def invalid_boolean(value)
      new(ErrorType::INVALID_BOOLEAN, "Invalid boolean value: #{value} (expected 0 or 1)")
    end

    def non_canonical_uleb128
      new(ErrorType::NON_CANONICAL_ULEB128, "ULEB128 encoding is not canonical (has trailing zeros)")
    end

    def uleb128_overflow
      new(ErrorType::ULEB128_OVERFLOW, "ULEB128 value overflows u32")
    end

    def exceeded_max_length(length)
      new(ErrorType::EXCEEDED_MAX_LENGTH,
          "Sequence length #{length} exceeds maximum #{MAX_SEQUENCE_LENGTH}")
    end

    def exceeded_container_depth(depth)
      new(ErrorType::EXCEEDED_CONTAINER_DEPTH,
          "Container depth #{depth} exceeds maximum #{MAX_CONTAINER_DEPTH}")
    end

    def invalid_utf8
      new(ErrorType::INVALID_UTF8, "Invalid UTF-8 encoding")
    end

    def non_canonical_map
      new(ErrorType::NON_CANONICAL_MAP, "Map keys are not in sorted order")
    end

    def duplicate_map_key
      new(ErrorType::DUPLICATE_MAP_KEY, "Duplicate key in map")
    end

    def integer_out_of_range(type_name)
      new(ErrorType::INTEGER_OUT_OF_RANGE, "Integer value out of range for #{type_name}")
    end

    def remaining_input(remaining)
      new(ErrorType::REMAINING_INPUT, "Input has #{remaining} remaining bytes after deserialization")
    end

    def invalid_option(value)
      new(ErrorType::INVALID_OPTION, "Invalid option tag: #{value} (expected 0 or 1)")
    end

  end
end
