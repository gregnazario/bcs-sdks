"""BCS Deserializer - Manual deserialization API."""

from __future__ import annotations

import struct
from typing import Any, Callable, TypeVar

from .errors import (
    ExceededContainerDepth,
    ExceededMaxLength,
    InvalidBoolean,
    InvalidOption,
    InvalidUtf8,
    NonCanonicalMap,
    NonCanonicalUleb128,
    RemainingInput,
    Uleb128Overflow,
    UnexpectedEof,
)
from .types import MAX_CONTAINER_DEPTH, MAX_SEQUENCE_LENGTH

T = TypeVar("T")

# Pre-compiled struct formats for performance
_STRUCT_U16 = struct.Struct("<H")
_STRUCT_U32 = struct.Struct("<I")
_STRUCT_U64 = struct.Struct("<Q")
_STRUCT_I8 = struct.Struct("<b")
_STRUCT_I16 = struct.Struct("<h")
_STRUCT_I32 = struct.Struct("<i")
_STRUCT_I64 = struct.Struct("<q")


class BcsDeserializer:
    """Manual BCS deserialization API.

    Provides explicit methods for deserializing each BCS type.
    Use this for full control over deserialization.

    Example:
        >>> d = BcsDeserializer(data)
        >>> value1 = d.read_u8()
        >>> value2 = d.read_u64()
        >>> value3 = d.read_string()
        >>> d.check_end()  # Verify no remaining bytes
    """

    __slots__ = ("_data", "_offset", "_len", "_max_depth", "_current_depth", "_max_alloc")

    def __init__(
        self,
        data: bytes | bytearray | memoryview,
        max_depth: int = MAX_CONTAINER_DEPTH,
        max_alloc: int | None = None,
    ) -> None:
        """Initialize a new deserializer.

        Args:
            data: Bytes to deserialize from
            max_depth: Maximum container nesting depth (default: 500)
            max_alloc: Maximum allocation size for vectors/bytes (default: MAX_SEQUENCE_LENGTH).
                       Set to a smaller value for defense-in-depth against memory exhaustion.
        """
        self._data = memoryview(data) if not isinstance(data, memoryview) else data
        self._offset = 0
        self._len = len(data)
        self._max_depth = max_depth
        self._current_depth = 0
        self._max_alloc = max_alloc if max_alloc is not None else MAX_SEQUENCE_LENGTH

    @property
    def remaining(self) -> int:
        """Number of bytes remaining to read."""
        return self._len - self._offset

    def check_end(self) -> None:
        """Verify all input has been consumed.

        Raises:
            RemainingInput: If bytes remain after deserialization
        """
        remaining = self._len - self._offset
        if remaining > 0:
            raise RemainingInput(remaining)

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

    def read_bool(self) -> bool:
        """Deserialize a boolean.

        Returns:
            Boolean value

        Raises:
            UnexpectedEof: If no bytes available
            InvalidBoolean: If byte is not 0x00 or 0x01
        """
        if self._offset >= self._len:
            raise UnexpectedEof(1, 0)
        byte = self._data[self._offset]
        self._offset += 1
        if byte == 0:
            return False
        elif byte == 1:
            return True
        else:
            raise InvalidBoolean(byte)

    # =========================================================================
    # UNSIGNED INTEGERS
    # =========================================================================

    def read_u8(self) -> int:
        """Deserialize an unsigned 8-bit integer.

        Returns:
            Integer in range [0, 255]
        """
        if self._offset >= self._len:
            raise UnexpectedEof(1, 0)
        value = self._data[self._offset]
        self._offset += 1
        return value

    def read_u16(self) -> int:
        """Deserialize an unsigned 16-bit integer (little-endian).

        Returns:
            Integer in range [0, 65535]
        """
        end = self._offset + 2
        if end > self._len:
            raise UnexpectedEof(2, self._len - self._offset)
        value = _STRUCT_U16.unpack(self._data[self._offset : end])[0]
        self._offset = end
        return value

    def read_u32(self) -> int:
        """Deserialize an unsigned 32-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^32-1]
        """
        end = self._offset + 4
        if end > self._len:
            raise UnexpectedEof(4, self._len - self._offset)
        value = _STRUCT_U32.unpack(self._data[self._offset : end])[0]
        self._offset = end
        return value

    def read_u64(self) -> int:
        """Deserialize an unsigned 64-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^64-1]
        """
        end = self._offset + 8
        if end > self._len:
            raise UnexpectedEof(8, self._len - self._offset)
        value = _STRUCT_U64.unpack(self._data[self._offset : end])[0]
        self._offset = end
        return value

    def read_u128(self) -> int:
        """Deserialize an unsigned 128-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^128-1]
        """
        end = self._offset + 16
        if end > self._len:
            raise UnexpectedEof(16, self._len - self._offset)
        value = int.from_bytes(self._data[self._offset : end], "little")
        self._offset = end
        return value

    def read_u256(self) -> int:
        """Deserialize an unsigned 256-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^256-1]
        """
        end = self._offset + 32
        if end > self._len:
            raise UnexpectedEof(32, self._len - self._offset)
        value = int.from_bytes(self._data[self._offset : end], "little")
        self._offset = end
        return value

    # =========================================================================
    # SIGNED INTEGERS (two's complement)
    # =========================================================================

    def read_i8(self) -> int:
        """Deserialize a signed 8-bit integer (two's complement).

        Returns:
            Integer in range [-128, 127]
        """
        if self._offset >= self._len:
            raise UnexpectedEof(1, 0)
        value = _STRUCT_I8.unpack(self._data[self._offset : self._offset + 1])[0]
        self._offset += 1
        return value

    def read_i16(self) -> int:
        """Deserialize a signed 16-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-32768, 32767]
        """
        end = self._offset + 2
        if end > self._len:
            raise UnexpectedEof(2, self._len - self._offset)
        value = _STRUCT_I16.unpack(self._data[self._offset : end])[0]
        self._offset = end
        return value

    def read_i32(self) -> int:
        """Deserialize a signed 32-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^31, 2^31-1]
        """
        end = self._offset + 4
        if end > self._len:
            raise UnexpectedEof(4, self._len - self._offset)
        value = _STRUCT_I32.unpack(self._data[self._offset : end])[0]
        self._offset = end
        return value

    def read_i64(self) -> int:
        """Deserialize a signed 64-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^63, 2^63-1]
        """
        end = self._offset + 8
        if end > self._len:
            raise UnexpectedEof(8, self._len - self._offset)
        value = _STRUCT_I64.unpack(self._data[self._offset : end])[0]
        self._offset = end
        return value

    def read_i128(self) -> int:
        """Deserialize a signed 128-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^127, 2^127-1]
        """
        end = self._offset + 16
        if end > self._len:
            raise UnexpectedEof(16, self._len - self._offset)
        value = int.from_bytes(self._data[self._offset : end], "little", signed=True)
        self._offset = end
        return value

    def read_i256(self) -> int:
        """Deserialize a signed 256-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^255, 2^255-1]
        """
        end = self._offset + 32
        if end > self._len:
            raise UnexpectedEof(32, self._len - self._offset)
        value = int.from_bytes(self._data[self._offset : end], "little", signed=True)
        self._offset = end
        return value

    # =========================================================================
    # ULEB128
    # =========================================================================

    def read_uleb128(self) -> int:
        """Deserialize a ULEB128-encoded unsigned integer.

        Returns:
            Non-negative integer fitting in u32

        Raises:
            UnexpectedEof: If input ends before ULEB128 is complete
            NonCanonicalUleb128: If encoding is not minimal
            Uleb128Overflow: If value exceeds u32 max
        """
        # Inline ULEB128 decoding for performance
        value = 0
        shift = 0
        data = self._data
        offset = self._offset
        data_len = self._len

        for i in range(5):  # Maximum 5 bytes for u32
            if offset + i >= data_len:
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
                if value > 0xFFFFFFFF:
                    raise Uleb128Overflow()

                self._offset = offset + i + 1
                return value

            shift += 7

        # If we get here, we read 5 bytes and all had continuation bits
        raise Uleb128Overflow()

    # =========================================================================
    # BYTES AND STRINGS
    # =========================================================================

    def read_bytes(self) -> bytes:
        """Deserialize a byte array (length-prefixed with ULEB128).

        Returns:
            Deserialized bytes

        Raises:
            ExceededMaxLength: If length exceeds max_alloc or MAX_SEQUENCE_LENGTH
        """
        length = self.read_uleb128()
        if length > self._max_alloc:
            raise ExceededMaxLength(length)
        end = self._offset + length
        if end > self._len:
            raise UnexpectedEof(length, self._len - self._offset)
        result = bytes(self._data[self._offset : end])
        self._offset = end
        return result

    def read_string(self) -> str:
        """Deserialize a UTF-8 string (length-prefixed with ULEB128).

        Returns:
            Deserialized string

        Raises:
            ExceededMaxLength: If length exceeds max_alloc
            InvalidUtf8: If bytes are not valid UTF-8
        """
        length = self.read_uleb128()
        if length > self._max_alloc:
            raise ExceededMaxLength(length)
        end = self._offset + length
        if end > self._len:
            raise UnexpectedEof(length, self._len - self._offset)
        try:
            # Decode directly from memoryview
            result = self._data[self._offset : end].tobytes().decode("utf-8")
        except UnicodeDecodeError as e:
            raise InvalidUtf8(str(e)) from e
        self._offset = end
        return result

    def read_fixed_bytes(self, length: int) -> bytes:
        """Deserialize fixed-length bytes (no length prefix).

        Args:
            length: Number of bytes to read

        Returns:
            Deserialized bytes
        """
        end = self._offset + length
        if end > self._len:
            raise UnexpectedEof(length, self._len - self._offset)
        result = bytes(self._data[self._offset : end])
        self._offset = end
        return result

    # =========================================================================
    # OPTION
    # =========================================================================

    def read_option(self, deserializer: Callable[["BcsDeserializer"], T]) -> T | None:
        """Deserialize an optional value.

        Args:
            deserializer: Function to deserialize the value if present

        Returns:
            The value or None

        Raises:
            InvalidOption: If tag byte is not 0x00 or 0x01
        """
        if self._offset >= self._len:
            raise UnexpectedEof(1, 0)
        tag = self._data[self._offset]
        self._offset += 1
        if tag == 0:
            return None
        elif tag == 1:
            return deserializer(self)
        else:
            raise InvalidOption(tag)

    def read_option_u8(self) -> int | None:
        """Deserialize an optional u8 (optimized)."""
        if self._offset >= self._len:
            raise UnexpectedEof(1, 0)
        tag = self._data[self._offset]
        self._offset += 1
        if tag == 0:
            return None
        elif tag == 1:
            return self.read_u8()
        else:
            raise InvalidOption(tag)

    def read_option_u64(self) -> int | None:
        """Deserialize an optional u64 (optimized)."""
        if self._offset >= self._len:
            raise UnexpectedEof(1, 0)
        tag = self._data[self._offset]
        self._offset += 1
        if tag == 0:
            return None
        elif tag == 1:
            return self.read_u64()
        else:
            raise InvalidOption(tag)

    def read_option_string(self) -> str | None:
        """Deserialize an optional string."""
        return self.read_option(lambda d: d.read_string())

    # =========================================================================
    # VECTOR
    # =========================================================================

    def read_vector(self, deserializer: Callable[["BcsDeserializer"], T]) -> list[T]:
        """Deserialize a vector of values.

        Args:
            deserializer: Function to deserialize each element

        Returns:
            List of deserialized values

        Raises:
            ExceededMaxLength: If length exceeds max_alloc
        """
        length = self.read_uleb128()
        if length > self._max_alloc:
            raise ExceededMaxLength(length)
        return [deserializer(self) for _ in range(length)]

    def read_vector_u8(self) -> list[int]:
        """Deserialize a vector of u8 (optimized - returns list of ints)."""
        length = self.read_uleb128()
        if length > self._max_alloc:
            raise ExceededMaxLength(length)
        end = self._offset + length
        if end > self._len:
            raise UnexpectedEof(length, self._len - self._offset)
        result = list(self._data[self._offset : end])
        self._offset = end
        return result

    def read_vector_u64(self) -> list[int]:
        """Deserialize a vector of u64 (optimized)."""
        length = self.read_uleb128()
        if length > self._max_alloc:
            raise ExceededMaxLength(length)
        # Check available bytes before computing byte_length to prevent overflow
        available = self._len - self._offset
        if length > available // 8:
            raise UnexpectedEof(length * 8, available)
        byte_length = length * 8
        end = self._offset + byte_length

        # Use iter_unpack for better performance on large vectors
        data = self._data[self._offset : end]
        result = [v for (v,) in struct.iter_unpack("<Q", data)]
        self._offset = end
        return result

    def read_vector_string(self) -> list[str]:
        """Deserialize a vector of strings."""
        return self.read_vector(lambda d: d.read_string())

    # =========================================================================
    # ENUM
    # =========================================================================

    def read_variant_index(self) -> int:
        """Read an enum variant index (ULEB128).

        Returns:
            Variant index (0-based)
        """
        self._check_depth("enum")
        return self.read_uleb128()

    def leave_enum(self) -> None:
        """Signal end of enum deserialization (for depth tracking)."""
        self._leave_container()

    # =========================================================================
    # STRUCT
    # =========================================================================

    def enter_struct(self, name: str = "") -> None:
        """Signal start of struct deserialization (for depth tracking).

        Args:
            name: Optional struct name for error messages
        """
        self._check_depth(name)

    def leave_struct(self) -> None:
        """Signal end of struct deserialization (for depth tracking)."""
        self._leave_container()

    # =========================================================================
    # MAP
    # =========================================================================

    def read_map(
        self,
        key_deserializer: Callable[["BcsDeserializer"], Any],
        value_deserializer: Callable[["BcsDeserializer"], Any],
    ) -> dict[Any, Any]:
        """Deserialize a map (verifying sorted keys).

        Args:
            key_deserializer: Function to deserialize keys
            value_deserializer: Function to deserialize values

        Returns:
            Deserialized dictionary

        Raises:
            ExceededMaxLength: If length exceeds max_alloc
            NonCanonicalMap: If keys are not sorted or contain duplicates
        """
        length = self.read_uleb128()
        if length > self._max_alloc:
            raise ExceededMaxLength(length)

        result: dict[Any, Any] = {}
        prev_key_bytes: bytes | None = None

        for _ in range(length):
            # Record position before reading key
            start_offset = self._offset

            key = key_deserializer(self)

            # Get the key bytes for comparison
            key_bytes = bytes(self._data[start_offset : self._offset])

            # Verify sorted order and no duplicates
            if prev_key_bytes is not None:
                if key_bytes <= prev_key_bytes:
                    if key_bytes == prev_key_bytes:
                        raise NonCanonicalMap("duplicate key")
                    else:
                        raise NonCanonicalMap("keys not sorted")

            prev_key_bytes = key_bytes
            value = value_deserializer(self)
            result[key] = value

        return result
