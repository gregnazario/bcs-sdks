@bcs
Feature: BCS Serialization
  As an SDK implementer
  I want to serialize and deserialize data in BCS format
  So that I can communicate with BCS-compatible systems

  # =============================================================================
  # BOOLEAN SERIALIZATION
  # =============================================================================
  
  @required @primitives
  Scenario Outline: Serialize boolean values
    Given a boolean value <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value | bcs_hex |
      | false | 00      |
      | true  | 01      |

  @required @primitives
  Scenario Outline: Deserialize boolean values
    Given BCS bytes "<bcs_hex>"
    When I deserialize as bool
    Then the result should be <value>

    Examples:
      | bcs_hex | value |
      | 00      | false |
      | 01      | true  |

  @required @primitives @error
  Scenario Outline: Reject invalid boolean values
    Given BCS bytes "<bcs_hex>"
    When I attempt to deserialize as bool
    Then deserialization should fail with error "InvalidBoolean"

    Examples:
      | bcs_hex |
      | 02      |
      | ff      |

  # =============================================================================
  # UNSIGNED INTEGER SERIALIZATION
  # =============================================================================

  @required @primitives
  Scenario Outline: Serialize u8 values
    Given a u8 value <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value | bcs_hex |
      | 0     | 00      |
      | 1     | 01      |
      | 127   | 7f      |
      | 128   | 80      |
      | 255   | ff      |

  @required @primitives
  Scenario Outline: Serialize u16 values (little-endian)
    Given a u16 value <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value | bcs_hex |
      | 0     | 0000    |
      | 1     | 0100    |
      | 256   | 0001    |
      | 4660  | 3412    |
      | 65535 | ffff    |

  @required @primitives
  Scenario Outline: Serialize u32 values (little-endian)
    Given a u32 value <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value      | bcs_hex  |
      | 0          | 00000000 |
      | 1          | 01000000 |
      | 305419896  | 78563412 |
      | 4294967295 | ffffffff |

  @required @primitives
  Scenario Outline: Serialize u64 values (little-endian)
    Given a u64 value "<value>"
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value                | bcs_hex          |
      | 0                    | 0000000000000000 |
      | 1                    | 0100000000000000 |
      | 100000000            | 00e1f50500000000 |
      | 18446744073709551615 | ffffffffffffffff |

  @required @primitives
  Scenario Outline: Serialize u128 values (little-endian)
    Given a u128 value "<value>"
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value                                   | bcs_hex                          |
      | 0                                       | 00000000000000000000000000000000 |
      | 1                                       | 01000000000000000000000000000000 |
      | 340282366920938463463374607431768211455 | ffffffffffffffffffffffffffffffff |

  @required @primitives
  Scenario Outline: Serialize u256 values (little-endian)
    Given a u256 value "<value>"
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value | bcs_hex                                                          |
      | 0     | 0000000000000000000000000000000000000000000000000000000000000000 |
      | 1     | 0100000000000000000000000000000000000000000000000000000000000000 |

  # =============================================================================
  # SIGNED INTEGER SERIALIZATION (TWO'S COMPLEMENT)
  # =============================================================================

  @required @primitives
  Scenario Outline: Serialize i8 values (two's complement)
    Given an i8 value <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value | bcs_hex |
      | 0     | 00      |
      | 1     | 01      |
      | -1    | ff      |
      | 127   | 7f      |
      | -128  | 80      |

  @required @primitives
  Scenario Outline: Serialize i16 values (two's complement, little-endian)
    Given an i16 value <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value  | bcs_hex |
      | 0      | 0000    |
      | 1      | 0100    |
      | -1     | ffff    |
      | 32767  | ff7f    |
      | -32768 | 0080    |

  @required @primitives
  Scenario Outline: Serialize i32 values (two's complement, little-endian)
    Given an i32 value <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value       | bcs_hex  |
      | 0           | 00000000 |
      | 1           | 01000000 |
      | -1          | ffffffff |
      | 2147483647  | ffffff7f |
      | -2147483648 | 00000080 |

  @required @primitives
  Scenario Outline: Serialize i64 values (two's complement, little-endian)
    Given an i64 value "<value>"
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value                | bcs_hex          |
      | 0                    | 0000000000000000 |
      | -1                   | ffffffffffffffff |
      | 9223372036854775807  | ffffffffffffff7f |
      | -9223372036854775808 | 0000000000000080 |

  # =============================================================================
  # ULEB128 ENCODING
  # =============================================================================

  @required @uleb128
  Scenario Outline: Encode ULEB128 values
    Given a length value <value>
    When I ULEB128 encode it
    Then the result should be "<bcs_hex>"

    Examples:
      | value      | bcs_hex    |
      | 0          | 00         |
      | 1          | 01         |
      | 127        | 7f         |
      | 128        | 8001       |
      | 255        | ff01       |
      | 16383      | ff7f       |
      | 16384      | 808001     |
      | 2097152    | 80808001   |
      | 268435456  | 8080808001 |

  @required @uleb128
  Scenario Outline: Decode ULEB128 values
    Given BCS bytes "<bcs_hex>"
    When I decode ULEB128
    Then the result should be <value>

    Examples:
      | bcs_hex    | value      |
      | 00         | 0          |
      | 01         | 1          |
      | 7f         | 127        |
      | 8001       | 128        |
      | ff01       | 255        |
      | ff7f       | 16383      |
      | 808001     | 16384      |
      | 80808001   | 2097152    |
      | 8080808001 | 268435456  |

  @required @uleb128 @error
  Scenario Outline: Reject non-canonical ULEB128 encodings
    Given BCS bytes "<bcs_hex>"
    When I attempt to decode ULEB128
    Then decoding should fail with error "NonCanonicalUleb128"

    Examples:
      | bcs_hex  | note                         |
      | 8000     | trailing zero for value 0    |
      | 8100     | trailing zero for value 1    |
      | 80810000 | extra zeros for value 128    |

  @required @uleb128 @error
  Scenario Outline: Reject ULEB128 overflow
    Given BCS bytes "<bcs_hex>"
    When I attempt to decode ULEB128
    Then decoding should fail with error "Uleb128Overflow"

    Examples:
      | bcs_hex        | note                |
      | 808080808001   | 6 bytes - too long  |
      | 8080808010     | exceeds u32 max     |

  # =============================================================================
  # BYTES AND STRINGS
  # =============================================================================

  @required @bytes
  Scenario Outline: Serialize byte arrays
    Given byte array <value>
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value       | bcs_hex    |
      | []          | 00         |
      | [42]        | 012a       |
      | [1, 2, 3]   | 03010203   |

  @required @strings
  Scenario Outline: Serialize strings (UTF-8)
    Given a string "<value>"
    When I BCS serialize it
    Then the result should be "<bcs_hex>"

    Examples:
      | value | bcs_hex            |
      |       | 00                 |
      | hello | 0568656c6c6f       |
      | héllo | 0668c3a96c6c6f     |

  @required @strings @error
  Scenario: Reject invalid UTF-8 during deserialization
    Given BCS bytes "01ff"
    When I attempt to deserialize as string
    Then deserialization should fail with error "InvalidUtf8"

  # =============================================================================
  # OPTION TYPES
  # =============================================================================

  @required @option
  Scenario: Serialize None option
    Given an Option with no value
    When I BCS serialize it
    Then the result should be "00"

  @required @option
  Scenario: Serialize Some(u64) option
    Given an Option<u64> containing value "42"
    When I BCS serialize it
    Then the result should be "012a00000000000000"

  @required @option @error
  Scenario Outline: Reject invalid option tags
    Given BCS bytes "<bcs_hex>"
    When I attempt to deserialize as Option<u8>
    Then deserialization should fail with error "InvalidOption"

    Examples:
      | bcs_hex |
      | 02      |
      | ff      |

  # =============================================================================
  # VECTORS (VARIABLE-LENGTH SEQUENCES)
  # =============================================================================

  @required @vector
  Scenario: Serialize empty vector
    Given an empty vector of u8
    When I BCS serialize it
    Then the result should be "00"

  @required @vector
  Scenario: Serialize vector of u8
    Given a vector of u8 [1, 2, 3]
    When I BCS serialize it
    Then the result should be "03010203"

  @required @vector
  Scenario: Serialize vector of u64
    Given a vector of u64 ["1", "2"]
    When I BCS serialize it
    Then the result should be "0201000000000000000200000000000000"

  @required @vector
  Scenario: Serialize nested vectors
    Given a vector of vectors [[1, 2], [3, 4]]
    When I BCS serialize it
    Then the result should be "04020102020304"

  @required @vector @error
  Scenario: Reject vector with length exceeding data
    Given BCS bytes "05010203"
    When I attempt to deserialize as vector<u8>
    Then deserialization should fail with error "UnexpectedEof"

  # =============================================================================
  # FIXED-LENGTH ARRAYS
  # =============================================================================

  @required @fixed_array
  Scenario: Serialize fixed-length array (no length prefix)
    Given a fixed array [u8; 3] with values [1, 2, 3]
    When I BCS serialize it
    Then the result should be "010203"

  @required @fixed_array
  Scenario: Serialize 32-byte address
    Given a fixed array [u8; 32] representing address "0x1"
    When I BCS serialize it
    Then the result should be "0000000000000000000000000000000000000000000000000000000000000001"

  # =============================================================================
  # STRUCTS
  # =============================================================================

  @required @structs
  Scenario: Serialize struct with multiple fields
    Given a struct with fields in order:
      | name   | type | value |
      | amount | u8   | 1     |
      | count  | u64  | 100   |
    When I BCS serialize it
    Then the result should be "016400000000000000"

  @required @structs
  Scenario: Serialize struct with string field
    Given a struct with fields in order:
      | name  | type   | value |
      | name  | string | test  |
      | value | u64    | 42    |
    When I BCS serialize it
    Then the result should be "04746573742a00000000000000"

  # =============================================================================
  # ENUMS
  # =============================================================================

  @required @enums
  Scenario: Serialize unit enum variant (index 0)
    Given an enum variant at index 0 with no data
    When I BCS serialize it
    Then the result should be "00"

  @required @enums
  Scenario: Serialize enum variant with data (index 1)
    Given an enum variant at index 1 with u64 value "42"
    When I BCS serialize it
    Then the result should be "012a00000000000000"

  @required @enums
  Scenario: Serialize enum variant with large index (128)
    Given an enum variant at index 128 with no data
    When I BCS serialize it
    Then the result should be "8001"
    # Note: 128 requires 2-byte ULEB128 encoding

  # =============================================================================
  # MAPS
  # =============================================================================

  @required @maps
  Scenario: Serialize empty map
    Given an empty map
    When I BCS serialize it
    Then the result should be "00"

  @required @maps
  Scenario: Serialize map with entries (sorted by key bytes)
    Given a map<u8, u8> with entries {1: 10, 2: 20, 3: 30}
    When I BCS serialize it
    Then the entries should be serialized in sorted key order
    And the result should be "03010a02140328"

  @required @maps @error
  Scenario: Reject map with unsorted keys
    Given BCS bytes "0302140110" representing map<u8, u8>
    When I attempt to deserialize as map<u8, u8>
    Then deserialization should fail with error "NonCanonicalMap"
    # Note: keys [2, 1] are not sorted

  @required @maps @error
  Scenario: Reject map with duplicate keys
    Given BCS bytes "0201100110" representing map<u8, u8>
    When I attempt to deserialize as map<u8, u8>
    Then deserialization should fail with error "NonCanonicalMap"
    # Note: key 1 appears twice

  # =============================================================================
  # ERROR CASES
  # =============================================================================

  @required @error
  Scenario: Fail on truncated data (u64)
    Given BCS bytes "01020304"
    When I attempt to deserialize as u64
    Then deserialization should fail with error "UnexpectedEof"

  @required @error
  Scenario: Fail on remaining input after deserialization
    Given BCS bytes "0100"
    When I attempt to deserialize as bool
    Then deserialization should fail with error "RemainingInput"

  @required @error
  Scenario: Fail on empty input
    Given BCS bytes ""
    When I attempt to deserialize as u8
    Then deserialization should fail with error "UnexpectedEof"

  # =============================================================================
  # ROUND-TRIP TESTS
  # =============================================================================

  @required @roundtrip
  Scenario Outline: Round-trip serialization preserves values
    Given a <type> value "<value>"
    When I serialize and then deserialize it
    Then the result should equal the original value

    Examples:
      | type    | value                |
      | bool    | true                 |
      | bool    | false                |
      | u8      | 0                    |
      | u8      | 255                  |
      | u64     | 18446744073709551615 |
      | i64     | -9223372036854775808 |
      | string  | hello world          |

  # =============================================================================
  # MANUAL SERIALIZATION API
  # =============================================================================

  @required @manual_api
  Scenario: Manual serialization with BcsSerializer
    Given a new BcsSerializer
    When I call write_u8(1)
    And I call write_u64(100)
    And I call write_string("test")
    And I call to_bytes()
    Then the result should be "016400000000000000047465737374"

  @required @manual_api
  Scenario: Manual deserialization with BcsDeserializer
    Given BCS bytes "016400000000000000047465737374"
    And a new BcsDeserializer with those bytes
    When I call read_u8()
    Then the result should be 1
    When I call read_u64()
    Then the result should be "100"
    When I call read_string()
    Then the result should be "test"
