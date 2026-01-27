"""BCS Deserializer - Manual deserialization API."""

from __future__ import annotations

from typing import Any, Callable, TypeVar

from . import uleb128
from .errors import (
    ExceededContainerDepth,
    ExceededMaxLength,
    InvalidBoolean,
    InvalidOption,
    InvalidUtf8,
    NonCanonicalMap,
    RemainingInput,
    UnexpectedEof,
)
from .types import MAX_CONTAINER_DEPTH, MAX_SEQUENCE_LENGTH

T = TypeVar("T")


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

    def __init__(
        self,
        data: bytes | bytearray | memoryview,
        max_depth: int = MAX_CONTAINER_DEPTH,
    ) -> None:
        """Initialize a new deserializer.

        Args:
            data: Bytes to deserialize from
            max_depth: Maximum container nesting depth (default: 500)
        """
        self._data = memoryview(data) if not isinstance(data, memoryview) else data
        self._offset = 0
        self._max_depth = max_depth
        self._current_depth = 0

    @property
    def remaining(self) -> int:
        """Number of bytes remaining to read."""
        return len(self._data) - self._offset

    def check_end(self) -> None:
        """Verify all input has been consumed.

        Raises:
            RemainingInput: If bytes remain after deserialization
        """
        if self.remaining > 0:
            raise RemainingInput(self.remaining)

    def _read_bytes(self, count: int) -> bytes:
        """Read exactly count bytes from input.

        Raises:
            UnexpectedEof: If insufficient bytes available
        """
        if self._offset + count > len(self._data):
            raise UnexpectedEof(count, self.remaining)
        result = bytes(self._data[self._offset : self._offset + count])
        self._offset += count
        return result

    def _peek_byte(self) -> int:
        """Peek at next byte without consuming it.

        Raises:
            UnexpectedEof: If no bytes available
        """
        if self._offset >= len(self._data):
            raise UnexpectedEof()
        return self._data[self._offset]

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
        byte = self._read_bytes(1)[0]
        if byte == 0x00:
            return False
        elif byte == 0x01:
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
        return self._read_bytes(1)[0]

    def read_u16(self) -> int:
        """Deserialize an unsigned 16-bit integer (little-endian).

        Returns:
            Integer in range [0, 65535]
        """
        return int.from_bytes(self._read_bytes(2), "little")

    def read_u32(self) -> int:
        """Deserialize an unsigned 32-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^32-1]
        """
        return int.from_bytes(self._read_bytes(4), "little")

    def read_u64(self) -> int:
        """Deserialize an unsigned 64-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^64-1]
        """
        return int.from_bytes(self._read_bytes(8), "little")

    def read_u128(self) -> int:
        """Deserialize an unsigned 128-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^128-1]
        """
        return int.from_bytes(self._read_bytes(16), "little")

    def read_u256(self) -> int:
        """Deserialize an unsigned 256-bit integer (little-endian).

        Returns:
            Integer in range [0, 2^256-1]
        """
        return int.from_bytes(self._read_bytes(32), "little")

    # =========================================================================
    # SIGNED INTEGERS (two's complement)
    # =========================================================================

    def read_i8(self) -> int:
        """Deserialize a signed 8-bit integer (two's complement).

        Returns:
            Integer in range [-128, 127]
        """
        return int.from_bytes(self._read_bytes(1), "little", signed=True)

    def read_i16(self) -> int:
        """Deserialize a signed 16-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-32768, 32767]
        """
        return int.from_bytes(self._read_bytes(2), "little", signed=True)

    def read_i32(self) -> int:
        """Deserialize a signed 32-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^31, 2^31-1]
        """
        return int.from_bytes(self._read_bytes(4), "little", signed=True)

    def read_i64(self) -> int:
        """Deserialize a signed 64-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^63, 2^63-1]
        """
        return int.from_bytes(self._read_bytes(8), "little", signed=True)

    def read_i128(self) -> int:
        """Deserialize a signed 128-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^127, 2^127-1]
        """
        return int.from_bytes(self._read_bytes(16), "little", signed=True)

    def read_i256(self) -> int:
        """Deserialize a signed 256-bit integer (two's complement, little-endian).

        Returns:
            Integer in range [-2^255, 2^255-1]
        """
        return int.from_bytes(self._read_bytes(32), "little", signed=True)

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
        value, self._offset = uleb128.decode(self._data, self._offset)
        return value

    # =========================================================================
    # BYTES AND STRINGS
    # =========================================================================

    def read_bytes(self) -> bytes:
        """Deserialize a byte array (length-prefixed with ULEB128).

        Returns:
            Deserialized bytes

        Raises:
            ExceededMaxLength: If length exceeds MAX_SEQUENCE_LENGTH
        """
        length = self.read_uleb128()
        if length > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(length)
        return self._read_bytes(length)

    def read_string(self) -> str:
        """Deserialize a UTF-8 string (length-prefixed with ULEB128).

        Returns:
            Deserialized string

        Raises:
            InvalidUtf8: If bytes are not valid UTF-8
        """
        data = self.read_bytes()
        try:
            return data.decode("utf-8")
        except UnicodeDecodeError as e:
            raise InvalidUtf8(str(e)) from e

    def read_fixed_bytes(self, length: int) -> bytes:
        """Deserialize fixed-length bytes (no length prefix).

        Args:
            length: Number of bytes to read

        Returns:
            Deserialized bytes
        """
        return self._read_bytes(length)

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
        tag = self._read_bytes(1)[0]
        if tag == 0x00:
            return None
        elif tag == 0x01:
            return deserializer(self)
        else:
            raise InvalidOption(tag)

    def read_option_u8(self) -> int | None:
        """Deserialize an optional u8."""
        return self.read_option(lambda d: d.read_u8())

    def read_option_u64(self) -> int | None:
        """Deserialize an optional u64."""
        return self.read_option(lambda d: d.read_u64())

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
            ExceededMaxLength: If length exceeds MAX_SEQUENCE_LENGTH
        """
        length = self.read_uleb128()
        if length > MAX_SEQUENCE_LENGTH:
            raise ExceededMaxLength(length)
        return [deserializer(self) for _ in range(length)]

    def read_vector_u8(self) -> list[int]:
        """Deserialize a vector of u8."""
        return self.read_vector(lambda d: d.read_u8())

    def read_vector_u64(self) -> list[int]:
        """Deserialize a vector of u64."""
        return self.read_vector(lambda d: d.read_u64())

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
            ExceededMaxLength: If length exceeds MAX_SEQUENCE_LENGTH
            NonCanonicalMap: If keys are not sorted or contain duplicates
        """
        length = self.read_uleb128()
        if length > MAX_SEQUENCE_LENGTH:
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
