# frozen_string_literal: true

module BCS
  # Maximum length for variable-length sequences (2^31 - 1)
  MAX_SEQUENCE_LENGTH = (1 << 31) - 1

  # Maximum container depth for nested structures
  MAX_CONTAINER_DEPTH = 500

  # Integer bounds (all frozen for thread safety)
  U8_MAX  = 0xFF
  U16_MAX = 0xFFFF
  U32_MAX = 0xFFFFFFFF
  U64_MAX = 0xFFFFFFFFFFFFFFFF
  U128_MAX = ((1 << 128) - 1)
  U256_MAX = ((1 << 256) - 1)

  I8_MIN  = -128
  I8_MAX  = 127
  I16_MIN = -32_768
  I16_MAX = 32_767
  I32_MIN = -2_147_483_648
  I32_MAX = 2_147_483_647
  I64_MIN = -9_223_372_036_854_775_808
  I64_MAX = 9_223_372_036_854_775_807
  I128_MIN = (-(1 << 127)).freeze
  I128_MAX = ((1 << 127) - 1)
  I256_MIN = (-(1 << 255)).freeze
  I256_MAX = ((1 << 255) - 1)

  # Pre-computed modulus values for signed integer operations
  MODULUS_128 = (1 << 128)
  MODULUS_256 = (1 << 256)

  # Pre-allocated byte strings for common values
  BYTE_FALSE = "\x00".b.freeze
  BYTE_TRUE = "\x01".b.freeze
end
