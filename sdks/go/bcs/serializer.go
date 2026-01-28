package bcs

import (
	"bytes"
	"encoding/binary"
	"math/big"
	"sort"
	"sync"
)

// MaxSequenceLength is the maximum allowed sequence length.
const MaxSequenceLength = (1 << 31) - 1

// MaxContainerDepth is the maximum allowed container nesting depth.
const MaxContainerDepth = 500

// defaultBufferCapacity is the default initial buffer size.
const defaultBufferCapacity = 256

// Pre-computed modulus values for signed integer serialization.
var (
	serModulus128  *big.Int
	serModulus256  *big.Int
	initSerOnce    sync.Once
)

func initSerConstants() {
	initSerOnce.Do(func() {
		serModulus128 = new(big.Int).Lsh(big.NewInt(1), 128)
		serModulus256 = new(big.Int).Lsh(big.NewInt(1), 256)
	})
}

// Serializer provides methods for BCS serialization.
type Serializer struct {
	buf   bytes.Buffer
	depth int
}

// serializerPool provides reusable Serializer instances.
var serializerPool = sync.Pool{
	New: func() interface{} {
		s := &Serializer{}
		s.buf.Grow(defaultBufferCapacity)
		return s
	},
}

// NewSerializer creates a new BCS serializer.
func NewSerializer() *Serializer {
	initSerConstants()
	s := &Serializer{}
	s.buf.Grow(defaultBufferCapacity)
	return s
}

// NewSerializerWithCapacity creates a new BCS serializer with pre-allocated buffer capacity.
// Use this when you know the approximate size of the output to reduce allocations.
func NewSerializerWithCapacity(capacity int) *Serializer {
	initSerConstants()
	s := &Serializer{}
	s.buf.Grow(capacity)
	return s
}

// AcquireSerializer gets a Serializer from the pool.
// Call ReleaseSerializer when done to return it to the pool.
func AcquireSerializer() *Serializer {
	initSerConstants()
	return serializerPool.Get().(*Serializer)
}

// ReleaseSerializer returns a Serializer to the pool for reuse.
// The serializer is reset before being returned to the pool.
func ReleaseSerializer(s *Serializer) {
	s.Reset()
	serializerPool.Put(s)
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
// Uses cached modulus to avoid repeated allocations.
func (s *Serializer) WriteI128(value *big.Int) *Serializer {
	unsigned := value
	if value.Sign() < 0 {
		unsigned = new(big.Int).Add(value, serModulus128)
	}
	s.writeBigIntLE(unsigned, 16)
	return s
}

// WriteI256 serializes a signed 256-bit integer (two's complement, little-endian).
// Uses cached modulus to avoid repeated allocations.
func (s *Serializer) WriteI256(value *big.Int) *Serializer {
	unsigned := value
	if value.Sign() < 0 {
		unsigned = new(big.Int).Add(value, serModulus256)
	}
	s.writeBigIntLE(unsigned, 32)
	return s
}

// ==========================================================================
// ULEB128
// ==========================================================================

// WriteULEB128 serializes a ULEB128-encoded unsigned integer.
// Writes directly to the buffer without intermediate allocation.
func (s *Serializer) WriteULEB128(value uint32) *Serializer {
	var buf [maxULEB128Bytes]byte
	n := encodeULEB128Into(buf[:], value)
	s.buf.Write(buf[:n])
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

// WriteRawBytes writes bytes directly without any length prefix or validation.
// Use this for performance-critical paths where you've already validated the data.
func (s *Serializer) WriteRawBytes(value []byte) *Serializer {
	s.buf.Write(value)
	return s
}

// ==========================================================================
// BATCH OPERATIONS
// ==========================================================================

// WriteU8Slice writes a slice of u8 values as a vector (length-prefixed).
// More efficient than calling WriteVectorLen + WriteU8 in a loop.
func (s *Serializer) WriteU8Slice(values []byte) *Serializer {
	if len(values) > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(len(values))))
	}
	s.WriteULEB128(uint32(len(values)))
	s.buf.Write(values)
	return s
}

// WriteU16Slice writes a slice of u16 values as a vector (length-prefixed).
func (s *Serializer) WriteU16Slice(values []uint16) *Serializer {
	if len(values) > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(len(values))))
	}
	s.WriteULEB128(uint32(len(values)))
	// Pre-allocate buffer for all values
	var buf [2]byte
	for _, v := range values {
		binary.LittleEndian.PutUint16(buf[:], v)
		s.buf.Write(buf[:])
	}
	return s
}

// WriteU32Slice writes a slice of u32 values as a vector (length-prefixed).
func (s *Serializer) WriteU32Slice(values []uint32) *Serializer {
	if len(values) > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(len(values))))
	}
	s.WriteULEB128(uint32(len(values)))
	var buf [4]byte
	for _, v := range values {
		binary.LittleEndian.PutUint32(buf[:], v)
		s.buf.Write(buf[:])
	}
	return s
}

// WriteU64Slice writes a slice of u64 values as a vector (length-prefixed).
func (s *Serializer) WriteU64Slice(values []uint64) *Serializer {
	if len(values) > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(len(values))))
	}
	s.WriteULEB128(uint32(len(values)))
	var buf [8]byte
	for _, v := range values {
		binary.LittleEndian.PutUint64(buf[:], v)
		s.buf.Write(buf[:])
	}
	return s
}

// WriteStringSlice writes a slice of strings as a vector (length-prefixed).
func (s *Serializer) WriteStringSlice(values []string) *Serializer {
	if len(values) > MaxSequenceLength {
		panic(NewExceededMaxLength(uint64(len(values))))
	}
	s.WriteULEB128(uint32(len(values)))
	for _, v := range values {
		s.WriteString(v)
	}
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
// CONTAINER DEPTH
// ==========================================================================

// ContainerDepth returns the current container nesting depth.
func (s *Serializer) ContainerDepth() int {
	return s.depth
}

// EnterStruct enters a struct container for depth tracking.
// Panics if container depth exceeds MaxContainerDepth (500).
func (s *Serializer) EnterStruct() *Serializer {
	s.enterContainer("struct")
	return s
}

// LeaveStruct leaves a struct container.
func (s *Serializer) LeaveStruct() *Serializer {
	s.leaveContainer()
	return s
}

// EnterEnum enters an enum container for depth tracking and writes the variant index.
// Panics if container depth exceeds MaxContainerDepth (500).
func (s *Serializer) EnterEnum(variantIndex uint32) *Serializer {
	s.enterContainer("enum")
	s.WriteVariantIndex(variantIndex)
	return s
}

// LeaveEnum leaves an enum container.
func (s *Serializer) LeaveEnum() *Serializer {
	s.leaveContainer()
	return s
}

func (s *Serializer) enterContainer(containerType string) {
	if s.depth >= MaxContainerDepth {
		panic(NewExceededContainerDepth(containerType))
	}
	s.depth++
}

func (s *Serializer) leaveContainer() {
	if s.depth > 0 {
		s.depth--
	}
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
	// Use stack-allocated arrays for common sizes to avoid heap allocation
	switch byteLength {
	case 16:
		var b [16]byte
		s.fillBigIntLE(b[:], value)
		s.buf.Write(b[:])
	case 32:
		var b [32]byte
		s.fillBigIntLE(b[:], value)
		s.buf.Write(b[:])
	default:
		// Fallback for other sizes (rare)
		b := make([]byte, byteLength)
		s.fillBigIntLE(b, value)
		s.buf.Write(b)
	}
}

// fillBigIntLE fills buf with the little-endian representation of value.
// buf must be zeroed or the caller must ensure proper initialization.
func (s *Serializer) fillBigIntLE(buf []byte, value *big.Int) {
	valueBytes := value.Bytes()
	// Copy in reverse order (big-endian to little-endian)
	for i := 0; i < len(valueBytes) && i < len(buf); i++ {
		buf[i] = valueBytes[len(valueBytes)-1-i]
	}
}
