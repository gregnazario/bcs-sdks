package bcs

import (
	"encoding/hex"
	"encoding/json"
	"math/big"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var testVectors map[string]interface{}

func TestMain(m *testing.M) {
	// Load test vectors
	vectorsPath := os.Getenv("TEST_VECTORS")
	if vectorsPath == "" {
		vectorsPath = "../../test-vectors"
	}
	data, err := os.ReadFile(filepath.Join(vectorsPath, "bcs-comprehensive.json"))
	if err == nil {
		_ = json.Unmarshal(data, &testVectors)
	}
	os.Exit(m.Run())
}

func hexToBytes(s string) []byte {
	b, _ := hex.DecodeString(s)
	return b
}

func bytesToHex(b []byte) string {
	return hex.EncodeToString(b)
}

func getTestVectors(path ...string) []map[string]interface{} {
	if testVectors == nil {
		return nil
	}
	var current interface{} = testVectors
	for _, key := range path {
		if m, ok := current.(map[string]interface{}); ok {
			current = m[key]
		} else {
			return nil
		}
	}
	if arr, ok := current.([]interface{}); ok {
		result := make([]map[string]interface{}, len(arr))
		for i, v := range arr {
			result[i] = v.(map[string]interface{})
		}
		return result
	}
	return nil
}

// ==========================================================================
// BOOLEAN TESTS
// ==========================================================================

func TestBoolSerialization(t *testing.T) {
	t.Run("serialize true", func(t *testing.T) {
		ser := NewSerializer()
		ser.WriteBool(true)
		assert.Equal(t, "01", bytesToHex(ser.Bytes()))
	})

	t.Run("serialize false", func(t *testing.T) {
		ser := NewSerializer()
		ser.WriteBool(false)
		assert.Equal(t, "00", bytesToHex(ser.Bytes()))
	})

	t.Run("deserialize true", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("01"))
		value, err := des.ReadBool()
		require.NoError(t, err)
		assert.True(t, value)
	})

	t.Run("deserialize false", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("00"))
		value, err := des.ReadBool()
		require.NoError(t, err)
		assert.False(t, value)
	})

	t.Run("reject invalid boolean", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("02"))
		_, err := des.ReadBool()
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrInvalidBoolean, bcsErr.Type)
	})
}

// ==========================================================================
// UNSIGNED INTEGER TESTS
// ==========================================================================

func TestU8Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "u8", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := uint8(tc["value"].(float64))
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteU8(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadU8()
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}
}

func TestU16Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "u16", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := uint16(tc["value"].(float64))
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteU16(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadU16()
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}
}

func TestU32Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "u32", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := uint32(tc["value"].(float64))
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteU32(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadU32()
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}
}

func TestU64Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "u64", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		valueStr := tc["value"].(string)
		value, _ := new(big.Int).SetString(valueStr, 10)
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteU64(value.Uint64())
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadU64()
			require.NoError(t, err)
			assert.Equal(t, value.Uint64(), result)
		})
	}
}

func TestU128Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "u128", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		valueStr := tc["value"].(string)
		value, _ := new(big.Int).SetString(valueStr, 10)
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteU128(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadU128()
			require.NoError(t, err)
			assert.Equal(t, 0, value.Cmp(result))
		})
	}
}

func TestU256Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "u256", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		valueStr := tc["value"].(string)
		value, _ := new(big.Int).SetString(valueStr, 10)
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteU256(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadU256()
			require.NoError(t, err)
			assert.Equal(t, 0, value.Cmp(result))
		})
	}
}

// ==========================================================================
// SIGNED INTEGER TESTS
// ==========================================================================

func TestI8Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "i8", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := int8(tc["value"].(float64))
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteI8(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadI8()
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}
}

func TestI16Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "i16", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := int16(tc["value"].(float64))
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteI16(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadI16()
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}
}

func TestI32Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "i32", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := int32(tc["value"].(float64))
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteI32(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadI32()
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}
}

func TestI64Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "i64", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		valueStr := tc["value"].(string)
		value, _ := new(big.Int).SetString(valueStr, 10)
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteI64(value.Int64())
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadI64()
			require.NoError(t, err)
			assert.Equal(t, value.Int64(), result)
		})
	}
}

func TestI128Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "i128", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		valueStr := tc["value"].(string)
		value, _ := new(big.Int).SetString(valueStr, 10)
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteI128(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadI128()
			require.NoError(t, err)
			assert.Equal(t, 0, value.Cmp(result))
		})
	}
}

func TestI256Serialization(t *testing.T) {
	vectors := getTestVectors("primitives", "i256", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		valueStr := tc["value"].(string)
		value, _ := new(big.Int).SetString(valueStr, 10)
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteI256(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadI256()
			require.NoError(t, err)
			assert.Equal(t, 0, value.Cmp(result))
		})
	}
}

// ==========================================================================
// ULEB128 TESTS
// ==========================================================================

func TestULEB128Encoding(t *testing.T) {
	vectors := getTestVectors("uleb128", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := uint32(tc["value"].(float64))
		bcsHex := tc["bcs_hex"].(string)

		t.Run("encode "+name, func(t *testing.T) {
			encoded := EncodeULEB128(value)
			assert.Equal(t, bcsHex, bytesToHex(encoded))
		})

		t.Run("decode "+name, func(t *testing.T) {
			result, _, err := DecodeULEB128(hexToBytes(bcsHex))
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}

	t.Run("reject non-canonical encoding", func(t *testing.T) {
		// 0x80 0x00 is non-canonical for 0
		_, _, err := DecodeULEB128([]byte{0x80, 0x00})
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrNonCanonicalULEB128, bcsErr.Type)
	})

	t.Run("reject overflow", func(t *testing.T) {
		// 6 bytes with continuation bits
		_, _, err := DecodeULEB128([]byte{0x80, 0x80, 0x80, 0x80, 0x80, 0x01})
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrULEB128Overflow, bcsErr.Type)
	})
}

// ==========================================================================
// STRING TESTS
// ==========================================================================

func TestStringSerialization(t *testing.T) {
	vectors := getTestVectors("strings", "valid")
	for _, tc := range vectors {
		name := tc["name"].(string)
		value := tc["value"].(string)
		bcsHex := tc["bcs_hex"].(string)

		t.Run("serialize "+name, func(t *testing.T) {
			ser := NewSerializer()
			ser.WriteString(value)
			assert.Equal(t, bcsHex, bytesToHex(ser.Bytes()))
		})

		t.Run("deserialize "+name, func(t *testing.T) {
			des := NewDeserializer(hexToBytes(bcsHex))
			result, err := des.ReadString()
			require.NoError(t, err)
			assert.Equal(t, value, result)
		})
	}

	t.Run("reject invalid UTF-8", func(t *testing.T) {
		// Length 1, byte 0xFF (invalid UTF-8)
		des := NewDeserializer([]byte{1, 0xFF})
		_, err := des.ReadString()
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrInvalidUTF8, bcsErr.Type)
	})
}

// ==========================================================================
// OPTION TESTS
// ==========================================================================

func TestOptionSerialization(t *testing.T) {
	t.Run("serialize None", func(t *testing.T) {
		ser := NewSerializer()
		ser.WriteOptionBool(false)
		assert.Equal(t, "00", bytesToHex(ser.Bytes()))
	})

	t.Run("serialize Some(42)", func(t *testing.T) {
		ser := NewSerializer()
		ser.WriteOptionBool(true)
		ser.WriteU8(42)
		assert.Equal(t, "012a", bytesToHex(ser.Bytes()))
	})

	t.Run("deserialize None", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("00"))
		hasValue, err := des.ReadOptionTag()
		require.NoError(t, err)
		assert.False(t, hasValue)
	})

	t.Run("deserialize Some(42)", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("012a"))
		hasValue, err := des.ReadOptionTag()
		require.NoError(t, err)
		assert.True(t, hasValue)
		value, err := des.ReadU8()
		require.NoError(t, err)
		assert.Equal(t, uint8(42), value)
	})

	t.Run("reject invalid option tag", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("02"))
		_, err := des.ReadOptionTag()
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrInvalidOption, bcsErr.Type)
	})
}

// ==========================================================================
// VECTOR TESTS
// ==========================================================================

func TestVectorSerialization(t *testing.T) {
	t.Run("serialize empty vector", func(t *testing.T) {
		ser := NewSerializer()
		ser.WriteVectorLen(0)
		assert.Equal(t, "00", bytesToHex(ser.Bytes()))
	})

	t.Run("serialize [1, 2, 3]", func(t *testing.T) {
		ser := NewSerializer()
		ser.WriteVectorLen(3)
		ser.WriteU8(1)
		ser.WriteU8(2)
		ser.WriteU8(3)
		assert.Equal(t, "03010203", bytesToHex(ser.Bytes()))
	})

	t.Run("deserialize empty vector", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("00"))
		length, err := des.ReadVectorLen()
		require.NoError(t, err)
		assert.Equal(t, uint32(0), length)
	})

	t.Run("deserialize [1, 2, 3]", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("03010203"))
		length, err := des.ReadVectorLen()
		require.NoError(t, err)
		assert.Equal(t, uint32(3), length)
		for i := 0; i < int(length); i++ {
			value, err := des.ReadU8()
			require.NoError(t, err)
			assert.Equal(t, uint8(i+1), value)
		}
	})
}

// ==========================================================================
// ERROR CASE TESTS
// ==========================================================================

func TestErrorCases(t *testing.T) {
	t.Run("remaining input", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("0001"))
		_, _ = des.ReadBool()
		err := des.CheckEnd()
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrRemainingInput, bcsErr.Type)
	})

	t.Run("unexpected EOF on u64", func(t *testing.T) {
		des := NewDeserializer(hexToBytes("010203"))
		_, err := des.ReadU64()
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrUnexpectedEOF, bcsErr.Type)
	})

	t.Run("unexpected EOF on empty input", func(t *testing.T) {
		des := NewDeserializer([]byte{})
		_, err := des.ReadU8()
		require.Error(t, err)
		var bcsErr *Error
		require.ErrorAs(t, err, &bcsErr)
		assert.Equal(t, ErrUnexpectedEOF, bcsErr.Type)
	})
}

// ==========================================================================
// ROUND-TRIP TESTS
// ==========================================================================

func TestRoundTrip(t *testing.T) {
	t.Run("complex struct", func(t *testing.T) {
		// Simulate a Transfer struct: sender (32 bytes), recipient (32 bytes), amount (u64)
		sender := make([]byte, 32)
		sender[31] = 1
		recipient := make([]byte, 32)
		recipient[31] = 2
		var amount uint64 = 1000000

		ser := NewSerializer()
		ser.WriteFixedBytes(sender, 32)
		ser.WriteFixedBytes(recipient, 32)
		ser.WriteU64(amount)
		data := ser.Bytes()

		des := NewDeserializer(data)
		readSender, err := des.ReadFixedBytes(32)
		require.NoError(t, err)
		readRecipient, err := des.ReadFixedBytes(32)
		require.NoError(t, err)
		readAmount, err := des.ReadU64()
		require.NoError(t, err)
		require.NoError(t, des.CheckEnd())

		assert.Equal(t, sender, readSender)
		assert.Equal(t, recipient, readRecipient)
		assert.Equal(t, amount, readAmount)
	})

	t.Run("nested vectors", func(t *testing.T) {
		values := [][]uint8{{1, 2}, {3, 4, 5}}

		ser := NewSerializer()
		ser.WriteVectorLen(len(values))
		for _, inner := range values {
			ser.WriteVectorLen(len(inner))
			for _, v := range inner {
				ser.WriteU8(v)
			}
		}
		data := ser.Bytes()

		des := NewDeserializer(data)
		outerLen, err := des.ReadVectorLen()
		require.NoError(t, err)
		result := make([][]uint8, outerLen)
		for i := range result {
			innerLen, err := des.ReadVectorLen()
			require.NoError(t, err)
			result[i] = make([]uint8, innerLen)
			for j := range result[i] {
				result[i][j], err = des.ReadU8()
				require.NoError(t, err)
			}
		}
		require.NoError(t, des.CheckEnd())

		assert.Equal(t, values, result)
	})
}

// ==========================================================================
// BATCH OPERATION TESTS
// ==========================================================================

func TestBatchOperations(t *testing.T) {
	t.Run("u8 slice round trip", func(t *testing.T) {
		values := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
		ser := NewSerializer()
		ser.WriteU8Slice(values)
		data := ser.Bytes()

		des := NewDeserializer(data)
		result, err := des.ReadU8Slice()
		require.NoError(t, err)
		assert.Equal(t, values, result)
	})

	t.Run("u64 slice round trip", func(t *testing.T) {
		values := []uint64{100, 200, 18446744073709551615, 0, 12345}
		ser := NewSerializer()
		ser.WriteU64Slice(values)
		data := ser.Bytes()

		des := NewDeserializer(data)
		result, err := des.ReadU64Slice()
		require.NoError(t, err)
		assert.Equal(t, values, result)
	})

	t.Run("string slice round trip", func(t *testing.T) {
		values := []string{"hello", "world", "BCS", ""}
		ser := NewSerializer()
		ser.WriteStringSlice(values)
		data := ser.Bytes()

		des := NewDeserializer(data)
		result, err := des.ReadStringSlice()
		require.NoError(t, err)
		assert.Equal(t, values, result)
	})
}

// ==========================================================================
// POOL TESTS
// ==========================================================================

func TestSerializerPool(t *testing.T) {
	t.Run("acquire and release", func(t *testing.T) {
		ser := AcquireSerializer()
		ser.WriteU64(12345)
		data := ser.Bytes()
		assert.Equal(t, "3930000000000000", bytesToHex(data))
		ReleaseSerializer(ser)

		// Acquire again - should be reset
		ser2 := AcquireSerializer()
		assert.Equal(t, 0, ser2.Len())
		ReleaseSerializer(ser2)
	})
}

func TestDeserializerPool(t *testing.T) {
	t.Run("acquire and release", func(t *testing.T) {
		data := hexToBytes("3930000000000000")
		des := AcquireDeserializer(data)
		val, err := des.ReadU64()
		require.NoError(t, err)
		assert.Equal(t, uint64(12345), val)
		ReleaseDeserializer(des)
	})
}

// ==========================================================================
// BENCHMARKS
// ==========================================================================

func BenchmarkSerializeU64(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		ser := NewSerializer()
		ser.WriteU64(uint64(i))
		_ = ser.Bytes()
	}
}

func BenchmarkSerializeU64WithPool(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		ser := AcquireSerializer()
		ser.WriteU64(uint64(i))
		_ = ser.Bytes()
		ReleaseSerializer(ser)
	}
}

func BenchmarkSerializeU128(b *testing.B) {
	b.ReportAllocs()
	value := big.NewInt(0).SetUint64(18446744073709551615)
	for i := 0; i < b.N; i++ {
		ser := NewSerializer()
		ser.WriteU128(value)
		_ = ser.Bytes()
	}
}

func BenchmarkSerializeULEB128(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		ser := NewSerializer()
		ser.WriteULEB128(uint32(i % 128))    // Single byte
		ser.WriteULEB128(uint32(16384 + i))  // Multi-byte
		_ = ser.Bytes()
	}
}

func BenchmarkDeserializeU64(b *testing.B) {
	data := hexToBytes("ffffffffffffffff")
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		des := NewDeserializer(data)
		_, _ = des.ReadU64()
	}
}

func BenchmarkDeserializeU64WithPool(b *testing.B) {
	data := hexToBytes("ffffffffffffffff")
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		des := AcquireDeserializer(data)
		_, _ = des.ReadU64()
		ReleaseDeserializer(des)
	}
}

func BenchmarkDeserializeU128(b *testing.B) {
	data := hexToBytes("ffffffffffffffffffffffffffffffff")
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		des := NewDeserializer(data)
		_, _ = des.ReadU128()
	}
}

func BenchmarkDeserializeULEB128(b *testing.B) {
	// Single byte value (0x7f = 127)
	data := hexToBytes("7f")
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		des := NewDeserializer(data)
		_, _ = des.ReadULEB128()
	}
}

func BenchmarkSerializeVector1000U64(b *testing.B) {
	values := make([]uint64, 1000)
	for i := range values {
		values[i] = uint64(i)
	}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ser := NewSerializerWithCapacity(8010) // Pre-allocate for better perf
		ser.WriteU64Slice(values)
		_ = ser.Bytes()
	}
}

func BenchmarkDeserializeVector1000U64(b *testing.B) {
	values := make([]uint64, 1000)
	for i := range values {
		values[i] = uint64(i)
	}
	ser := NewSerializer()
	ser.WriteU64Slice(values)
	data := ser.Bytes()
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		des := NewDeserializer(data)
		_, _ = des.ReadU64Slice()
	}
}
