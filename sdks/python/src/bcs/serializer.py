"""BCS Serializer - Manual serialization API."""

from __future__ import annotations

import struct
from typing import Any, Callable, Sequence, TypeVar

from .errors import ExceededContainerDepth, ExceededMaxLength
from .types import (
    I8_MAX,
    I8_MIN,
    I16_MAX,
    I16_MIN,
    I32_MAX,
    I32_MIN,
    I64_MAX,
    I64_MIN,
    I128_MAX,
    I128_MIN,
    I256_MAX,
    I256_MIN,
    MAX_CONTAINER_DEPTH,
    MAX_SEQUENCE_LENGTH,
    U8_MAX,
    U16_MAX,
    U32_MAX,
    U64_MAX,
    U128_MAX,
    U256_MAX,
)

T = TypeVar("T")

# Pre-compiled struct formats for performance
_STRUCT_U16 = struct.Struct("<H")
_STRUCT_U32 = struct.Struct("<I")
_STRUCT_U64 = struct.Struct("<Q")
_STRUCT_I16 = struct.Struct("<h")
_STRUCT_I32 = struct.Struct("<i")
_STRUCT_I64 = struct.Struct("<q")


class BcsSerializer:
    """Manual BCS serialization API.

    Provides explicit methods for serializing each BCS type.
    Use this for full control over serialization.

    Example:
        >>> s = BcsSerializer()
        >>> s.write_u8(1)
        >>> s.write_u64(100)
        >>> s.write_string("hello")
        >>> data = s.to_bytes()
    """

    __slots__ = ("_buffer", "_max_depth", "_current_depth")

    def __init__(self, max_depth: int = MAX_CONTAINER_DEPTH) -> None:
        """Initialize a new serializer.

        Args:
            max_depth: Maximum container nesting depth (default: 500)
        """
        self._buffer = bytearray()
        self._max_depth = max_depth
        self._current_depth = 0

    def to_bytes(self) -> bytes:
        """Get the serialized bytes.

        Returns:
            The accumulated serialized data
        """
        return bytes(self._buffer)

    def _check_depth(self, container: str = "") -> None:
        """Check and increment container depth."""
        if self._current_depth >= self._max_depth:
            raise ExceededContainerDepth(container)
        self._current_depth += 1

    def _leave_container(self) -> None:
        """Decrement container depth."""
        if self._current_depth > 0:
            self._current_depth -= 1

    # =========================================================================
    # BOOLEAN
    # =========================================================================

    def write_bool(self, value: bool) -> "BcsSerializer":
        """Serialize a boolean.

        Args:
            value: Boolean value to serialize

        Returns:
            self for chaining
        """
        self._buffer.append(1 if value else 0)
        return self

    # =========================================================================
    # UNSIGNED INTEGERS
    # =========================================================================

    def write_u8(self, value: int) -> "BcsSerializer":
        """Serialize an unsigned 8-bit integer.

        Args:
            value: Integer in range [0, 255]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not 0 <= value <= U8_MAX:
            raise ValueError(f"u8 value out of range: {value}")
        self._buffer.append(value)
        return self

    def write_u16(self, value: int) -> "BcsSerializer":
        """Serialize an unsigned 16-bit integer (little-endian).

        Args:
            value: Integer in range [0, 65535]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not 0 <= value <= U16_MAX:
            raise ValueError(f"u16 value out of range: {value}")
        self._buffer += _STRUCT_U16.pack(value)
        return self

    def write_u32(self, value: int) -> "BcsSerializer":
        """Serialize an unsigned 32-bit integer (little-endian).

        Args:
            value: Integer in range [0, 2^32-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not 0 <= value <= U32_MAX:
            raise ValueError(f"u32 value out of range: {value}")
        self._buffer += _STRUCT_U32.pack(value)
        return self

    def write_u64(self, value: int) -> "BcsSerializer":
        """Serialize an unsigned 64-bit integer (little-endian).

        Args:
            value: Integer in range [0, 2^64-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not 0 <= value <= U64_MAX:
            raise ValueError(f"u64 value out of range: {value}")
        self._buffer += _STRUCT_U64.pack(value)
        return self

    def write_u128(self, value: int) -> "BcsSerializer":
        """Serialize an unsigned 128-bit integer (little-endian).

        Args:
            value: Integer in range [0, 2^128-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not 0 <= value <= U128_MAX:
            raise ValueError(f"u128 value out of range: {value}")
        self._buffer += value.to_bytes(16, "little")
        return self

    def write_u256(self, value: int) -> "BcsSerializer":
        """Serialize an unsigned 256-bit integer (little-endian).

        Args:
            value: Integer in range [0, 2^256-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not 0 <= value <= U256_MAX:
            raise ValueError(f"u256 value out of range: {value}")
        self._buffer += value.to_bytes(32, "little")
        return self

    # =========================================================================
    # SIGNED INTEGERS (two's complement)
    # =========================================================================

    def write_i8(self, value: int) -> "BcsSerializer":
        """Serialize a signed 8-bit integer (two's complement).

        Args:
            value: Integer in range [-128, 127]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not I8_MIN <= value <= I8_MAX:
            raise ValueError(f"i8 value out of range: {value}")
        self._buffer.append(value & 0xFF)
        return self

    def write_i16(self, value: int) -> "BcsSerializer":
        """Serialize a signed 16-bit integer (two's complement, little-endian).

        Args:
            value: Integer in range [-32768, 32767]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not I16_MIN <= value <= I16_MAX:
            raise ValueError(f"i16 value out of range: {value}")
        self._buffer += _STRUCT_I16.pack(value)
        return self

    def write_i32(self, value: int) -> "BcsSerializer":
        """Serialize a signed 32-bit integer (two's complement, little-endian).

        Args:
            value: Integer in range [-2^31, 2^31-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not I32_MIN <= value <= I32_MAX:
            raise ValueError(f"i32 value out of range: {value}")
        self._buffer += _STRUCT_I32.pack(value)
        return self

    def write_i64(self, value: int) -> "BcsSerializer":
        """Serialize a signed 64-bit integer (two's complement, little-endian).

        Args:
            value: Integer in range [-2^63, 2^63-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not I64_MIN <= value <= I64_MAX:
            raise ValueError(f"i64 value out of range: {value}")
        self._buffer += _STRUCT_I64.pack(value)
        return self

    def write_i128(self, value: int) -> "BcsSerializer":
        """Serialize a signed 128-bit integer (two's complement, little-endian).

        Args:
            value: Integer in range [-2^127, 2^127-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not I128_MIN <= value <= I128_MAX:
            raise ValueError(f"i128 value out of range: {value}")
        self._buffer += value.to_bytes(16, "little", signed=True)
        return self

    def write_i256(self, value: int) -> "BcsSerializer":
        """Serialize a signed 256-bit integer (two's complement, little-endian).

        Args:
            value: Integer in range [-2^255, 2^255-1]

        Returns:
            self for chaining

        Raises:
            ValueError: If value is out of range
        """
        if not I256_MIN <= value <= I256_MAX:
            raise ValueError(f"i256 value out of range: {value}")
        self._buffer += value.to_bytes(32, "little", signed=True)
        return self

    # =========================================================================
    # ULEB128
    # =========================================================================

    def write_uleb128(self, value: int) -> "BcsSerializer":
        """Serialize a ULEB128-encoded unsigned integer.

        Args:
            value: Non-negative integer fitting in u32

        Returns:
            self for chaining
        """
        # Inline ULEB128 encoding for performance
        if value < 0:
            raise ValueError(f"ULEB128 cannot encode negative values: {value}")
        if value > 0xFFFFFFFF:
            raise ValueError(f"ULEB128 value exceeds u32 max: {value}")

        buf = self._buffer
        while value >= 0x80:
            buf.append((value & 0x7F) | 0x80)
            value >>= 7
        buf.append(value)
        return self

    # =========================================================================
    # BYTES AND STRINGS
    # =========================================================================

    def write_bytes(self, value: bytes | bytearray) -> "BcsSerializer":
        """Serialize a byte array (length-prefixed with ULEB128).

        Args:
            value: Bytes to serialize

        Returns:
            self for chaining

        Raises:
            ExceededMaxLength: If length exceeds MAX_SEQUENCE_LENGTH
        """
        length = len(value)
        if length > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(length)
        self.write_uleb128(length)
        self._buffer += value
        return self

    def write_string(self, value: str) -> "BcsSerializer":
        """Serialize a UTF-8 string (length-prefixed with ULEB128).

        Args:
            value: String to serialize

        Returns:
            self for chaining
        """
        encoded = value.encode("utf-8")
        length = len(encoded)
        if length > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(length)
        self.write_uleb128(length)
        self._buffer += encoded
        return self

    def write_fixed_bytes(self, value: bytes | bytearray, length: int) -> "BcsSerializer":
        """Serialize fixed-length bytes (no length prefix).

        Args:
            value: Bytes to serialize
            length: Expected length

        Returns:
            self for chaining

        Raises:
            ValueError: If value length doesn't match expected length
        """
        if len(value) != length:
            raise ValueError(f"Expected {length} bytes, got {len(value)}")
        self._buffer += value
        return self

    # =========================================================================
    # OPTION
    # =========================================================================

    def write_option(
        self, value: T | None, serializer: Callable[["BcsSerializer", T], None]
    ) -> "BcsSerializer":
        """Serialize an optional value.

        Args:
            value: The value or None
            serializer: Function to serialize the value if present

        Returns:
            self for chaining
        """
        if value is None:
            self._buffer.append(0x00)
        else:
            self._buffer.append(0x01)
            serializer(self, value)
        return self

    def write_option_u8(self, value: int | None) -> "BcsSerializer":
        """Serialize an optional u8."""
        return self.write_option(value, lambda s, v: s.write_u8(v))

    def write_option_u64(self, value: int | None) -> "BcsSerializer":
        """Serialize an optional u64."""
        return self.write_option(value, lambda s, v: s.write_u64(v))

    def write_option_string(self, value: str | None) -> "BcsSerializer":
        """Serialize an optional string."""
        return self.write_option(value, lambda s, v: s.write_string(v))

    # =========================================================================
    # VECTOR
    # =========================================================================

    def write_vector(
        self, values: Sequence[T], serializer: Callable[["BcsSerializer", T], None]
    ) -> "BcsSerializer":
        """Serialize a vector of values.

        Args:
            values: Sequence of values to serialize
            serializer: Function to serialize each element

        Returns:
            self for chaining

        Raises:
            ExceededMaxLength: If length exceeds MAX_SEQUENCE_LENGTH
        """
        if len(values) > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(len(values))
        self.write_uleb128(len(values))
        for value in values:
            serializer(self, value)
        return self

    def write_vector_u8(self, values: Sequence[int]) -> "BcsSerializer":
        """Serialize a vector of u8 (optimized)."""
        length = len(values)
        if length > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(length)
        self.write_uleb128(length)
        # Fast path: if it's already bytes-like, extend directly
        if isinstance(values, (bytes, bytearray)):
            self._buffer += values
        else:
            # Validate all values are in u8 range before conversion
            for v in values:
                if not 0 <= v <= U8_MAX:
                    raise ValueError(f"u8 value out of range: {v}")
            self._buffer += bytes(values)
        return self

    def write_vector_u64(self, values: Sequence[int]) -> "BcsSerializer":
        """Serialize a vector of u64 (optimized)."""
        length = len(values)
        if length > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(length)
        self.write_uleb128(length)
        buf = self._buffer
        pack = _STRUCT_U64.pack
        for v in values:
            if not 0 <= v <= U64_MAX:
                raise ValueError(f"u64 value out of range: {v}")
            buf += pack(v)
        return self

    def write_vector_string(self, values: Sequence[str]) -> "BcsSerializer":
        """Serialize a vector of strings."""
        return self.write_vector(values, lambda s, v: s.write_string(v))

    # =========================================================================
    # ENUM
    # =========================================================================

    def write_variant_index(self, index: int) -> "BcsSerializer":
        """Write an enum variant index (ULEB128).

        Args:
            index: Variant index (0-based)

        Returns:
            self for chaining
        """
        self._check_depth("enum")
        self.write_uleb128(index)
        return self

    def leave_enum(self) -> "BcsSerializer":
        """Signal end of enum serialization (for depth tracking)."""
        self._leave_container()
        return self

    # =========================================================================
    # STRUCT
    # =========================================================================

    def enter_struct(self, name: str = "") -> "BcsSerializer":
        """Signal start of struct serialization (for depth tracking).

        Args:
            name: Optional struct name for error messages

        Returns:
            self for chaining
        """
        self._check_depth(name)
        return self

    def leave_struct(self) -> "BcsSerializer":
        """Signal end of struct serialization (for depth tracking)."""
        self._leave_container()
        return self

    # =========================================================================
    # MAP
    # =========================================================================

    def write_map(
        self,
        items: dict[Any, Any],
        key_serializer: Callable[["BcsSerializer", Any], None],
        value_serializer: Callable[["BcsSerializer", Any], None],
    ) -> "BcsSerializer":
        """Serialize a map (sorted by key bytes).

        Args:
            items: Dictionary to serialize
            key_serializer: Function to serialize keys
            value_serializer: Function to serialize values

        Returns:
            self for chaining
        """
        if len(items) > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(len(items))

        # Serialize each key to get bytes for sorting
        key_bytes_pairs: list[tuple[bytes, Any, Any]] = []
        for key, value in items.items():
            key_ser = BcsSerializer()
            key_serializer(key_ser, key)
            key_bytes_pairs.append((key_ser.to_bytes(), key, value))

        # Sort by key bytes
        key_bytes_pairs.sort(key=lambda x: x[0])

        # Write length and sorted entries
        self.write_uleb128(len(key_bytes_pairs))
        for key_bytes, key, value in key_bytes_pairs:
            self._buffer += key_bytes
            value_serializer(self, value)

        return self
