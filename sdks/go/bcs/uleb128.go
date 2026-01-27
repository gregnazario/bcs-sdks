package bcs

// MaxU32 is the maximum value for ULEB128 encoding.
const MaxU32 = 0xFFFFFFFF

// maxULEB128Bytes is the maximum number of bytes needed to encode a u32 in ULEB128.
const maxULEB128Bytes = 5

// EncodeULEB128 encodes an unsigned integer as ULEB128.
// Uses a stack-allocated array to avoid heap allocation.
func EncodeULEB128(value uint32) []byte {
	var buf [maxULEB128Bytes]byte
	n := encodeULEB128Into(buf[:], value)
	// Return a copy to avoid returning a slice of a stack array
	result := make([]byte, n)
	copy(result, buf[:n])
	return result
}

// encodeULEB128Into writes the ULEB128 encoding of value into buf.
// Returns the number of bytes written. buf must have at least 5 bytes capacity.
func encodeULEB128Into(buf []byte, value uint32) int {
	if value == 0 {
		buf[0] = 0
		return 1
	}

	i := 0
	remaining := value
	for remaining > 0 {
		b := byte(remaining & 0x7F)
		remaining >>= 7
		if remaining != 0 {
			b |= 0x80
		}
		buf[i] = b
		i++
	}
	return i
}

// DecodeULEB128 decodes a ULEB128 value from a byte slice.
// Returns the decoded value, bytes consumed, and any error.
func DecodeULEB128(data []byte) (uint32, int, error) {
	return DecodeULEB128WithOffset(data, 0)
}

// DecodeULEB128WithOffset decodes a ULEB128 value from a byte slice at the given offset.
func DecodeULEB128WithOffset(data []byte, offset int) (uint32, int, error) {
	var value uint32
	var shift uint
	bytesRead := 0

	for {
		if offset+bytesRead >= len(data) {
			return 0, 0, NewUnexpectedEOF()
		}

		b := data[offset+bytesRead]
		bytesRead++

		// Check for overflow (5 bytes max for u32)
		if bytesRead == 5 {
			if b >= 0x10 {
				return 0, 0, NewULEB128Overflow()
			}
			value |= uint32(b) << shift
			if value > MaxU32 {
				return 0, 0, NewULEB128Overflow()
			}
			return value, bytesRead, nil
		}

		digit := b & 0x7F
		value |= uint32(digit) << shift

		if b&0x80 == 0 {
			// Last byte - check for non-canonical encoding
			if bytesRead > 1 && b == 0 {
				return 0, 0, NewNonCanonicalULEB128()
			}
			return value, bytesRead, nil
		}

		shift += 7
	}
}

// EncodedSizeULEB128 returns the number of bytes needed to encode a value.
func EncodedSizeULEB128(value uint32) int {
	if value == 0 {
		return 1
	}

	size := 0
	remaining := value
	for remaining > 0 {
		remaining >>= 7
		size++
	}
	return size
}
