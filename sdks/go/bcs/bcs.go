// Package bcs provides Binary Canonical Serialization for Go.
//
// BCS is a deterministic binary serialization format that guarantees
// canonical representation - every value has exactly one valid encoding.
//
// # Quick Start
//
//	// Serialization
//	ser := bcs.NewSerializer()
//	ser.WriteU8(1)
//	ser.WriteU64(100)
//	ser.WriteString("hello")
//	bytes := ser.Bytes()
//
//	// Deserialization
//	des := bcs.NewDeserializer(bytes)
//	v1, _ := des.ReadU8()
//	v2, _ := des.ReadU64()
//	v3, _ := des.ReadString()
//	des.CheckEnd()
//
// # Supported Types
//
// - Booleans: bool
// - Unsigned integers: u8, u16, u32, u64, u128, u256
// - Signed integers: i8, i16, i32, i64, i128, i256
// - Byte arrays: bytes (length-prefixed)
// - Strings: string (UTF-8, length-prefixed)
// - Fixed bytes: fixed_bytes (no length prefix)
// - Options: option (0x00 for None, 0x01 for Some)
// - Vectors: vector (length-prefixed)
// - Maps: map (length-prefixed, sorted by key bytes)
// - Enums: via variant index
//
// # Constants
//
// - MaxSequenceLength: 2^31 - 1 (2,147,483,647)
// - MaxContainerDepth: 500
package bcs

// SerializeU8 serializes a u8 value.
func SerializeU8(value uint8) []byte {
	return []byte{value}
}

// SerializeU64 serializes a u64 value.
func SerializeU64(value uint64) []byte {
	ser := NewSerializer()
	ser.WriteU64(value)
	return ser.Bytes()
}

// SerializeString serializes a string value.
func SerializeString(value string) []byte {
	ser := NewSerializer()
	ser.WriteString(value)
	return ser.Bytes()
}

// SerializeBytes serializes a bytes value.
func SerializeBytes(value []byte) []byte {
	ser := NewSerializer()
	ser.WriteBytes(value)
	return ser.Bytes()
}

// DeserializeU8 deserializes a u8 value.
func DeserializeU8(data []byte) (uint8, error) {
	des := NewDeserializer(data)
	value, err := des.ReadU8()
	if err != nil {
		return 0, err
	}
	if err := des.CheckEnd(); err != nil {
		return 0, err
	}
	return value, nil
}

// DeserializeU64 deserializes a u64 value.
func DeserializeU64(data []byte) (uint64, error) {
	des := NewDeserializer(data)
	value, err := des.ReadU64()
	if err != nil {
		return 0, err
	}
	if err := des.CheckEnd(); err != nil {
		return 0, err
	}
	return value, nil
}

// DeserializeString deserializes a string value.
func DeserializeString(data []byte) (string, error) {
	des := NewDeserializer(data)
	value, err := des.ReadString()
	if err != nil {
		return "", err
	}
	if err := des.CheckEnd(); err != nil {
		return "", err
	}
	return value, nil
}

// DeserializeBytes deserializes a bytes value.
func DeserializeBytes(data []byte) ([]byte, error) {
	des := NewDeserializer(data)
	value, err := des.ReadBytes()
	if err != nil {
		return nil, err
	}
	if err := des.CheckEnd(); err != nil {
		return nil, err
	}
	return value, nil
}
