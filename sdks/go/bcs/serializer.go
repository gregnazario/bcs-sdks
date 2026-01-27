package bcs

import (
	"bytes"
	"encoding/binary"
	"math/big"
	"sort"
)

// MaxSequenceLength is the maximum allowed sequence length.
const MaxSequenceLength = (1 << 31) - 1

// MaxContainerDepth is the maximum allowed container nesting depth.
const MaxContainerDepth = 500

// Serializer provides methods for BCS serialization.
type Serializer struct {
	buf bytes.Buffer
}

// NewSerializer creates a new BCS serializer.
func NewSerializer() *Serializer {
	return &Serializer{}
}

// ==========================================================================
// BOOLEAN
// ==========================================================================

// WriteBool serializes a boolean value.
func (s *Serializer) WriteBool(value bool) *Serializer {
	if value {
		s.buf.WriteByte(1)
	} else {
		s.buf.WriteByte(0)
	}
	return s
}

// ==========================================================================
// UNSIGNED INTEGERS
// ==========================================================================

// WriteU8 serializes an unsigned 8-bit integer.
func (s *Serializer) WriteU8(value uint8) *Serializer {
	s.buf.WriteByte(value)
	return s
}

// WriteU16 serializes an unsigned 16-bit integer (little-endian).
func (s *Serializer) WriteU16(value uint16) *Serializer {
	var b [2]byte
	binary.LittleEndian.PutUint16(b[:], value)
	s.buf.Write(b[:])
	return s
}

// WriteU32 serializes an unsigned 32-bit integer (little-endian).
func (s *Serializer) WriteU32(value uint32) *Serializer {
	var b [4]byte
	binary.LittleEndian.PutUint32(b[:], value)
	s.buf.Write(b[:])
	return s
}

// WriteU64 serializes an unsigned 64-bit integer (little-endian).
func (s *Serializer) WriteU64(value uint64) *Serializer {
	var b [8]byte
	binary.LittleEndian.PutUint64(b[:], value)
	s.buf.Write(b[:])
	return s
}

// WriteU128 serializes an unsigned 128-bit integer (little-endian).
func (s *Serializer) WriteU128(value *big.Int) *Serializer {
	s.writeBigIntLE(value, 16)
	return s
}

// WriteU256 serializes an unsigned 256-bit integer (little-endian).
func (s *Serializer) WriteU256(value *big.Int) *Serializer {
	s.writeBigIntLE(value, 32)
	return s
}

// ==========================================================================
// SIGNED INTEGERS
// ==========================================================================

// WriteI8 serializes a signed 8-bit integer (two's complement).
func (s *Serializer) WriteI8(value int8) *Serializer {
	s.buf.WriteByte(byte(value))
	return s
}

// WriteI16 serializes a signed 16-bit integer (two's complement, little-endian).
func (s *Serializer) WriteI16(value int16) *Serializer {
	var b [2]byte
	binary.LittleEndian.PutUint16(b[:], uint16(value))
	s.buf.Write(b[:])
	return s
}

// WriteI32 serializes a signed 32-bit integer (two's complement, little-endian).
func (s *Serializer) WriteI32(value int32) *Serializer {
	var b [4]byte
	binary.LittleEndian.PutUint32(b[:], uint32(value))
	s.buf.Write(b[:])
	return s
}

// WriteI64 serializes a signed 64-bit integer (two's complement, little-endian).
func (s *Serializer) WriteI64(value int64) *Serializer {
	var b [8]byte
	binary.LittleEndian.PutUint64(b[:], uint64(value))
	s.buf.Write(b[:])
	return s
}

// WriteI128 serializes a signed 128-bit integer (two's complement, little-endian).
func (s *Serializer) WriteI128(value *big.Int) *Serializer {
	unsigned := value
	if value.Sign() < 0 {
		unsigned = new(big.Int).Add(value, new(big.Int).Lsh(big.NewInt(1), 128))
	}
	s.writeBigIntLE(unsigned, 16)
	return s
}

// WriteI256 serializes a signed 256-bit integer (two's complement, little-endian).
func (s *Serializer) WriteI256(value *big.Int) *Serializer {
	unsigned := value
	if value.Sign() < 0 {
		unsigned = new(big.Int).Add(value, new(big.Int).Lsh(big.NewInt(1), 256))
	}
	s.writeBigIntLE(unsigned, 32)
	return s
}

// ==========================================================================
// ULEB128
// ==========================================================================

// WriteULEB128 serializes a ULEB128-encoded unsigned integer.
func (s *Serializer) WriteULEB128(value uint32) *Serializer {
	encoded := EncodeULEB128(value)
	s.buf.Write(encoded)
	return s
}

// ==========================================================================
// BYTES AND STRINGS
// ==========================================================================

// WriteBytes serializes a byte slice (length-prefixed with ULEB128).
func (s *Serializer) WriteBytes(value []byte) *Serializer {
	if len(value) > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(len(value))))
	}
	s.WriteULEB128(uint32(len(value)))
	s.buf.Write(value)
	return s
}

// WriteString serializes a UTF-8 string (length-prefixed with ULEB128).
func (s *Serializer) WriteString(value string) *Serializer {
	return s.WriteBytes([]byte(value))
}

// WriteFixedBytes serializes fixed-length bytes (no length prefix).
func (s *Serializer) WriteFixedBytes(value []byte, length int) *Serializer {
	if len(value) != length {
		panic(NewValueOutOfRange("fixed_bytes", len(value)))
	}
	s.buf.Write(value)
	return s
}

// ==========================================================================
// OPTION
// ==========================================================================

// WriteOptionBool writes the option tag for a value.
// Returns true if the serializer should continue writing the value.
func (s *Serializer) WriteOptionBool(hasValue bool) *Serializer {
	if hasValue {
		s.buf.WriteByte(1)
	} else {
		s.buf.WriteByte(0)
	}
	return s
}

// ==========================================================================
// VECTOR
// ==========================================================================

// WriteVectorLen writes the length prefix for a vector.
func (s *Serializer) WriteVectorLen(length int) *Serializer {
	if length > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(length)))
	}
	s.WriteULEB128(uint32(length))
	return s
}

// ==========================================================================
// ENUM
// ==========================================================================

// WriteVariantIndex writes an enum variant index (ULEB128).
func (s *Serializer) WriteVariantIndex(index uint32) *Serializer {
	return s.WriteULEB128(index)
}

// ==========================================================================
// MAP
// ==========================================================================

// MapEntry represents a key-value pair for map serialization.
type MapEntry struct {
	KeyBytes []byte
	Value    any
}

// WriteMapLen writes the length prefix for a map.
func (s *Serializer) WriteMapLen(length int) *Serializer {
	if length > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(length)))
	}
	s.WriteULEB128(uint32(length))
	return s
}

// SortMapEntries sorts map entries by their serialized key bytes.
func SortMapEntries(entries []MapEntry) {
	sort.Slice(entries, func(i, j int) bool {
		return bytes.Compare(entries[i].KeyBytes, entries[j].KeyBytes) < 0
	})
}

// ==========================================================================
// UTILITY
// ==========================================================================

// Bytes returns the serialized bytes.
func (s *Serializer) Bytes() []byte {
	return s.buf.Bytes()
}

// Len returns the current length in bytes.
func (s *Serializer) Len() int {
	return s.buf.Len()
}

// Reset clears the serializer for reuse.
func (s *Serializer) Reset() {
	s.buf.Reset()
}

// ==========================================================================
// PRIVATE HELPERS
// ==========================================================================

func (s *Serializer) writeBigIntLE(value *big.Int, byteLength int) {
	b := make([]byte, byteLength)
	valueBytes := value.Bytes()

	// Copy in reverse order (big-endian to little-endian)
	for i := 0; i < len(valueBytes) && i < byteLength; i++ {
		b[i] = valueBytes[len(valueBytes)-1-i]
	}

	s.buf.Write(b)
}
