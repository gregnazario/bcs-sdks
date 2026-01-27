"""ULEB128 encoding and decoding for BCS."""

from __future__ import annotations

from .errors import NonCanonicalUleb128, Uleb128Overflow, UnexpectedEof

# Maximum value that can be encoded (u32 max)
MAX_U32 = 0xFFFFFFFF


def encode(value: int) -> bytes:
    """Encode an unsigned integer as ULEB128.

    Args:
        value: Non-negative integer to encode (must fit in u32)

    Returns:
        ULEB128 encoded bytes

    Raises:
        ValueError: If value is negative or exceeds u32 max
    """
    if value < 0:
        raise ValueError(f"ULEB128 cannot encode negative values: {value}")
    if value > MAX_U32:
        raise ValueError(f"ULEB128 value exceeds u32 max: {value}")

    result = bytearray()
    while value >= 0x80:
        # Write 7 bits with continuation bit set
        result.append((value & 0x7F) | 0x80)
        value >>= 7
    # Write final byte without continuation bit
    result.append(value)
    return bytes(result)


def decode(data: bytes | bytearray | memoryview, offset: int = 0) -> tuple[int, int]:
    """Decode a ULEB128 value from bytes.

    Args:
        data: Bytes to decode from
        offset: Starting position in data

    Returns:
        Tuple of (decoded value, new offset after reading)

    Raises:
        UnexpectedEof: If data ends before ULEB128 is complete
        NonCanonicalUleb128: If encoding is not minimal (has trailing zeros)
        Uleb128Overflow: If value exceeds u32 max or encoding is too long
    """
    value = 0
    shift = 0

    for i in range(5):  # Maximum 5 bytes for u32
        if offset + i >= len(data):
            raise UnexpectedEof()

        byte = data[offset + i]
        digit = byte & 0x7F
        value |= digit << shift

        # Check if this is the last byte (high bit is 0)
        if digit == byte:
            # Reject non-canonical encodings (trailing zero bytes)
            if shift > 0 and digit == 0:
                raise NonCanonicalUleb128()

            # Check for overflow
            if value > MAX_U32:
                raise Uleb128Overflow()

            return value, offset + i + 1

        shift += 7

    # If we get here, we read 5 bytes and all had continuation bits
    raise Uleb128Overflow()


def encoded_size(value: int) -> int:
    """Calculate the number of bytes needed to encode a value.

    Args:
        value: Non-negative integer

    Returns:
        Number of bytes required for ULEB128 encoding
    """
    if value == 0:
        return 1
    size = 0
    while value > 0:
        size += 1
        value >>= 7
    return size
