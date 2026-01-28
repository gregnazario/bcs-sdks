package bcs

import (
	"encoding/binary"
	"math/big"
	"sync"
	"unicode/utf8"
)

// Pre-computed constants for signed integer conversion to avoid repeated allocations.
var (
	signBit128  *big.Int
	signBit256  *big.Int
	modulus128  *big.Int
	modulus256  *big.Int
	initBigOnce sync.Once
)

func initBigConstants() {
	initBigOnce.Do(func() {
		signBit128 = new(big.Int).Lsh(big.NewInt(1), 127)
		signBit256 = new(big.Int).Lsh(big.NewInt(1), 255)
		modulus128 = new(big.Int).Lsh(big.NewInt(1), 128)
		modulus256 = new(big.Int).Lsh(big.NewInt(1), 256)
	})
}

// Deserializer provides methods for BCS deserialization.
type Deserializer struct {
	data   []byte
	offset int
	depth  int
}

// deserializerPool provides reusable Deserializer instances.
var deserializerPool = sync.Pool{
	New: func() interface{} {
		return &Deserializer{}
	},
}

// NewDeserializer creates a new BCS deserializer.
func NewDeserializer(data []byte) *Deserializer {
	initBigConstants()
	return &Deserializer{data: data, offset: 0}
}

// AcquireDeserializer gets a Deserializer from the pool and initializes it with data.
// Call ReleaseDeserializer when done to return it to the pool.
func AcquireDeserializer(data []byte) *Deserializer {
	initBigConstants()
	d := deserializerPool.Get().(*Deserializer)
	d.data = data
	d.offset = 0
	return d
}

// ReleaseDeserializer returns a Deserializer to the pool for reuse.
func ReleaseDeserializer(d *Deserializer) {
	d.data = nil
	d.offset = 0
	deserializerPool.Put(d)
}

// ==========================================================================
// BOOLEAN
// ==========================================================================

// ReadBool deserializes a boolean value.
func (d *Deserializer) ReadBool() (bool, error) {
	if err := d.ensureBytes(1); err != nil {
		return false, err
	}
	b := d.data[d.offset]
	d.offset++
	switch b {
	case 0:
		return false, nil
	case 1:
		return true, nil
	default:
		return false, NewInvalidBoolean(b)
	}
}

// ==========================================================================
// UNSIGNED INTEGERS
// ==========================================================================

// ReadU8 deserializes an unsigned 8-bit integer.
func (d *Deserializer) ReadU8() (uint8, error) {
	if err := d.ensureBytes(1); err != nil {
		return 0, err
	}
	value := d.data[d.offset]
	d.offset++
	return value, nil
}

// ReadU16 deserializes an unsigned 16-bit integer (little-endian).
func (d *Deserializer) ReadU16() (uint16, error) {
	if err := d.ensureBytes(2); err != nil {
		return 0, err
	}
	value := binary.LittleEndian.Uint16(d.data[d.offset:])
	d.offset += 2
	return value, nil
}

// ReadU32 deserializes an unsigned 32-bit integer (little-endian).
func (d *Deserializer) ReadU32() (uint32, error) {
	if err := d.ensureBytes(4); err != nil {
		return 0, err
	}
	value := binary.LittleEndian.Uint32(d.data[d.offset:])
	d.offset += 4
	return value, nil
}

// ReadU64 deserializes an unsigned 64-bit integer (little-endian).
func (d *Deserializer) ReadU64() (uint64, error) {
	if err := d.ensureBytes(8); err != nil {
		return 0, err
	}
	value := binary.LittleEndian.Uint64(d.data[d.offset:])
	d.offset += 8
	return value, nil
}

// ReadU128 deserializes an unsigned 128-bit integer (little-endian).
func (d *Deserializer) ReadU128() (*big.Int, error) {
	if err := d.ensureBytes(16); err != nil {
		return nil, err
	}
	return d.readBigIntLE(16), nil
}

// ReadU256 deserializes an unsigned 256-bit integer (little-endian).
func (d *Deserializer) ReadU256() (*big.Int, error) {
	if err := d.ensureBytes(32); err != nil {
		return nil, err
	}
	return d.readBigIntLE(32), nil
}

// ==========================================================================
// SIGNED INTEGERS
// ==========================================================================

// ReadI8 deserializes a signed 8-bit integer (two's complement).
func (d *Deserializer) ReadI8() (int8, error) {
	u, err := d.ReadU8()
	if err != nil {
		return 0, err
	}
	return int8(u), nil
}

// ReadI16 deserializes a signed 16-bit integer (two's complement, little-endian).
func (d *Deserializer) ReadI16() (int16, error) {
	u, err := d.ReadU16()
	if err != nil {
		return 0, err
	}
	return int16(u), nil
}

// ReadI32 deserializes a signed 32-bit integer (two's complement, little-endian).
func (d *Deserializer) ReadI32() (int32, error) {
	u, err := d.ReadU32()
	if err != nil {
		return 0, err
	}
	return int32(u), nil
}

// ReadI64 deserializes a signed 64-bit integer (two's complement, little-endian).
func (d *Deserializer) ReadI64() (int64, error) {
	u, err := d.ReadU64()
	if err != nil {
		return 0, err
	}
	return int64(u), nil
}

// ReadI128 deserializes a signed 128-bit integer (two's complement, little-endian).
// Uses cached constants to avoid repeated allocations.
func (d *Deserializer) ReadI128() (*big.Int, error) {
	unsigned, err := d.ReadU128()
	if err != nil {
		return nil, err
	}
	if unsigned.Cmp(signBit128) >= 0 {
		return new(big.Int).Sub(unsigned, modulus128), nil
	}
	return unsigned, nil
}

// ReadI256 deserializes a signed 256-bit integer (two's complement, little-endian).
// Uses cached constants to avoid repeated allocations.
func (d *Deserializer) ReadI256() (*big.Int, error) {
	unsigned, err := d.ReadU256()
	if err != nil {
		return nil, err
	}
	if unsigned.Cmp(signBit256) >= 0 {
		return new(big.Int).Sub(unsigned, modulus256), nil
	}
	return unsigned, nil
}

// ==========================================================================
// ULEB128
// ==========================================================================

// ReadULEB128 deserializes a ULEB128-encoded unsigned integer.
// Inlined for performance on the hot path.
func (d *Deserializer) ReadULEB128() (uint32, error) {
	// Fast path: single byte (values 0-127)
	if d.offset >= len(d.data) {
		return 0, NewUnexpectedEOF()
	}
	b := d.data[d.offset]
	if b < 0x80 {
		d.offset++
		return uint32(b), nil
	}

	// Slow path: multi-byte encoding
	value, bytesRead, err := DecodeULEB128WithOffset(d.data, d.offset)
	if err != nil {
		return 0, err
	}
	d.offset += bytesRead
	return value, nil
}

// ==========================================================================
// BYTES AND STRINGS
// ==========================================================================

// ReadBytes deserializes a byte slice (length-prefixed with ULEB128).
func (d *Deserializer) ReadBytes() ([]byte, error) {
	length, err := d.ReadULEB128()
	if err != nil {
		return nil, err
	}
	if length > MaxSequenceLength {
		return nil, NewExceededMaxLength(uint64(length))
	}
	return d.ReadFixedBytes(int(length))
}

// ReadString deserializes a UTF-8 string (length-prefixed with ULEB128).
func (d *Deserializer) ReadString() (string, error) {
	b, err := d.ReadBytes()
	if err != nil {
		return "", err
	}
	if !utf8.Valid(b) {
		return "", NewInvalidUTF8("")
	}
	return string(b), nil
}

// ReadFixedBytes deserializes fixed-length bytes (no length prefix).
// Returns a copy of the bytes.
func (d *Deserializer) ReadFixedBytes(length int) ([]byte, error) {
	if err := d.ensureBytes(length); err != nil {
		return nil, err
	}
	result := make([]byte, length)
	copy(result, d.data[d.offset:d.offset+length])
	d.offset += length
	return result, nil
}

// ReadFixedBytesNoCopy deserializes fixed-length bytes without copying.
// WARNING: The returned slice is a view into the deserializer's internal buffer.
// Do not modify the returned slice and do not use it after the deserializer
// is released or reused. Use ReadFixedBytes if you need to own the data.
func (d *Deserializer) ReadFixedBytesNoCopy(length int) ([]byte, error) {
	if err := d.ensureBytes(length); err != nil {
		return nil, err
	}
	result := d.data[d.offset : d.offset+length]
	d.offset += length
	return result, nil
}

// ==========================================================================
// OPTION
// ==========================================================================

// ReadOptionTag reads the option tag and returns whether a value is present.
func (d *Deserializer) ReadOptionTag() (bool, error) {
	if err := d.ensureBytes(1); err != nil {
		return false, err
	}
	tag := d.data[d.offset]
	d.offset++
	switch tag {
	case 0:
		return false, nil
	case 1:
		return true, nil
	default:
		return false, NewInvalidOption(tag)
	}
}

// ==========================================================================
// VECTOR
// ==========================================================================

// ReadVectorLen reads the length prefix for a vector.
func (d *Deserializer) ReadVectorLen() (uint32, error) {
	length, err := d.ReadULEB128()
	if err != nil {
		return 0, err
	}
	if length > MaxSequenceLength {
		return 0, NewExceededMaxLength(uint64(length))
	}
	return length, nil
}

// ==========================================================================
// ENUM
// ==========================================================================

// ReadVariantIndex reads an enum variant index (ULEB128).
func (d *Deserializer) ReadVariantIndex() (uint32, error) {
	return d.ReadULEB128()
}

// ==========================================================================
// CONTAINER DEPTH
// ==========================================================================

// ContainerDepth returns the current container nesting depth.
func (d *Deserializer) ContainerDepth() int {
	return d.depth
}

// EnterStruct enters a struct container for depth tracking.
// Returns an error if container depth exceeds MaxContainerDepth (500).
func (d *Deserializer) EnterStruct() error {
	return d.enterContainer("struct")
}

// LeaveStruct leaves a struct container.
func (d *Deserializer) LeaveStruct() {
	d.leaveContainer()
}

// EnterEnum enters an enum container for depth tracking and reads the variant index.
// Returns the variant index and an error if container depth exceeds MaxContainerDepth (500).
func (d *Deserializer) EnterEnum() (uint32, error) {
	if err := d.enterContainer("enum"); err != nil {
		return 0, err
	}
	return d.ReadVariantIndex()
}

// LeaveEnum leaves an enum container.
func (d *Deserializer) LeaveEnum() {
	d.leaveContainer()
}

func (d *Deserializer) enterContainer(containerType string) error {
	if d.depth >= MaxContainerDepth {
		return NewExceededContainerDepth(containerType)
	}
	d.depth++
	return nil
}

func (d *Deserializer) leaveContainer() {
	if d.depth > 0 {
		d.depth--
	}
}

// ==========================================================================
// MAP
// ==========================================================================

// ReadMapLen reads the length prefix for a map.
func (d *Deserializer) ReadMapLen() (uint32, error) {
	return d.ReadVectorLen()
}

// Position returns the current read position for key comparison.
func (d *Deserializer) Position() int {
	return d.offset
}

// SliceFrom returns a slice of the data from start to current position.
func (d *Deserializer) SliceFrom(start int) []byte {
	return d.data[start:d.offset]
}

// ==========================================================================
// BATCH OPERATIONS
// ==========================================================================

// ReadU8Slice reads a vector of u8 values (length-prefixed).
// More efficient than calling ReadVectorLen + ReadU8 in a loop.
// Returns a copy of the data.
func (d *Deserializer) ReadU8Slice() ([]byte, error) {
	length, err := d.ReadVectorLen()
	if err != nil {
		return nil, err
	}
	return d.ReadFixedBytes(int(length))
}

// ReadU8SliceNoCopy reads a vector of u8 values without copying.
// WARNING: The returned slice is a view into the deserializer's internal buffer.
func (d *Deserializer) ReadU8SliceNoCopy() ([]byte, error) {
	length, err := d.ReadVectorLen()
	if err != nil {
		return nil, err
	}
	return d.ReadFixedBytesNoCopy(int(length))
}

// ReadU16Slice reads a vector of u16 values (length-prefixed).
func (d *Deserializer) ReadU16Slice() ([]uint16, error) {
	length, err := d.ReadVectorLen()
	if err != nil {
		return nil, err
	}
	if err := d.ensureBytes(int(length) * 2); err != nil {
		return nil, err
	}
	result := make([]uint16, length)
	for i := range result {
		result[i] = binary.LittleEndian.Uint16(d.data[d.offset:])
		d.offset += 2
	}
	return result, nil
}

// ReadU32Slice reads a vector of u32 values (length-prefixed).
func (d *Deserializer) ReadU32Slice() ([]uint32, error) {
	length, err := d.ReadVectorLen()
	if err != nil {
		return nil, err
	}
	if err := d.ensureBytes(int(length) * 4); err != nil {
		return nil, err
	}
	result := make([]uint32, length)
	for i := range result {
		result[i] = binary.LittleEndian.Uint32(d.data[d.offset:])
		d.offset += 4
	}
	return result, nil
}

// ReadU64Slice reads a vector of u64 values (length-prefixed).
func (d *Deserializer) ReadU64Slice() ([]uint64, error) {
	length, err := d.ReadVectorLen()
	if err != nil {
		return nil, err
	}
	if err := d.ensureBytes(int(length) * 8); err != nil {
		return nil, err
	}
	result := make([]uint64, length)
	for i := range result {
		result[i] = binary.LittleEndian.Uint64(d.data[d.offset:])
		d.offset += 8
	}
	return result, nil
}

// ReadStringSlice reads a vector of strings (length-prefixed).
func (d *Deserializer) ReadStringSlice() ([]string, error) {
	length, err := d.ReadVectorLen()
	if err != nil {
		return nil, err
	}
	result := make([]string, length)
	for i := range result {
		result[i], err = d.ReadString()
		if err != nil {
			return nil, err
		}
	}
	return result, nil
}

// ==========================================================================
// UTILITY
// ==========================================================================

// CheckEnd verifies that all input has been consumed.
func (d *Deserializer) CheckEnd() error {
	if d.offset < len(d.data) {
		return NewRemainingInput(len(d.data) - d.offset)
	}
	return nil
}

// Remaining returns the number of remaining bytes.
func (d *Deserializer) Remaining() int {
	return len(d.data) - d.offset
}

// ==========================================================================
// PRIVATE HELPERS
// ==========================================================================

func (d *Deserializer) ensureBytes(count int) error {
	if d.offset+count > len(d.data) {
		return NewUnexpectedEOFWithDetails(count, len(d.data)-d.offset)
	}
	return nil
}

func (d *Deserializer) readBigIntLE(byteLength int) *big.Int {
	// Use stack-allocated arrays for common sizes to avoid heap allocation
	switch byteLength {
	case 16:
		var b [16]byte
		for i := 0; i < 16; i++ {
			b[15-i] = d.data[d.offset+i]
		}
		d.offset += 16
		return new(big.Int).SetBytes(b[:])
	case 32:
		var b [32]byte
		for i := 0; i < 32; i++ {
			b[31-i] = d.data[d.offset+i]
		}
		d.offset += 32
		return new(big.Int).SetBytes(b[:])
	default:
		// Fallback for other sizes (rare)
		b := make([]byte, byteLength)
		for i := 0; i < byteLength; i++ {
			b[byteLength-1-i] = d.data[d.offset+i]
		}
		d.offset += byteLength
		return new(big.Int).SetBytes(b)
	}
}
