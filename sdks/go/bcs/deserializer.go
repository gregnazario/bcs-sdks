package bcs

import (
	"encoding/binary"
	"math/big"
	"unicode/utf8"
)

// Deserializer provides methods for BCS deserialization.
type Deserializer struct {
	data   []byte
	offset int
}

// NewDeserializer creates a new BCS deserializer.
func NewDeserializer(data []byte) *Deserializer {
	return &Deserializer{data: data, offset: 0}
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
func (d *Deserializer) ReadI128() (*big.Int, error) {
	unsigned, err := d.ReadU128()
	if err != nil {
		return nil, err
	}
	signBit := new(big.Int).Lsh(big.NewInt(1), 127)
	if unsigned.Cmp(signBit) >= 0 {
		return new(big.Int).Sub(unsigned, new(big.Int).Lsh(big.NewInt(1), 128)), nil
	}
	return unsigned, nil
}

// ReadI256 deserializes a signed 256-bit integer (two's complement, little-endian).
func (d *Deserializer) ReadI256() (*big.Int, error) {
	unsigned, err := d.ReadU256()
	if err != nil {
		return nil, err
	}
	signBit := new(big.Int).Lsh(big.NewInt(1), 255)
	if unsigned.Cmp(signBit) >= 0 {
		return new(big.Int).Sub(unsigned, new(big.Int).Lsh(big.NewInt(1), 256)), nil
	}
	return unsigned, nil
}

// ==========================================================================
// ULEB128
// ==========================================================================

// ReadULEB128 deserializes a ULEB128-encoded unsigned integer.
func (d *Deserializer) ReadULEB128() (uint32, error) {
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
func (d *Deserializer) ReadFixedBytes(length int) ([]byte, error) {
	if err := d.ensureBytes(length); err != nil {
		return nil, err
	}
	result := make([]byte, length)
	copy(result, d.data[d.offset:d.offset+length])
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
	// Read little-endian bytes and convert to big-endian for big.Int
	b := make([]byte, byteLength)
	for i := 0; i < byteLength; i++ {
		b[byteLength-1-i] = d.data[d.offset+i]
	}
	d.offset += byteLength
	return new(big.Int).SetBytes(b)
}
