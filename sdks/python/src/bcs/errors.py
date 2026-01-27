"""BCS error types."""

from __future__ import annotations


class BcsError(Exception):
    """Base class for all BCS errors."""

    pass


class UnexpectedEof(BcsError):
    """Raised when input ends unexpectedly during deserialization."""

    def __init__(self, expected: int = 0, available: int = 0) -> None:
        if expected and available:
            super().__init__(f"Unexpected end of input: expected {expected} bytes, got {available}")
        else:
            super().__init__("Unexpected end of input")


class InvalidBoolean(BcsError):
    """Raised when deserializing an invalid boolean value."""

    def __init__(self, value: int) -> None:
        super().__init__(f"Invalid boolean value: 0x{value:02x} (expected 0x00 or 0x01)")


class InvalidOption(BcsError):
    """Raised when deserializing an invalid option tag."""

    def __init__(self, value: int) -> None:
        super().__init__(f"Invalid option tag: 0x{value:02x} (expected 0x00 or 0x01)")


class InvalidUtf8(BcsError):
    """Raised when deserializing invalid UTF-8 data."""

    def __init__(self, message: str = "Invalid UTF-8 encoding") -> None:
        super().__init__(message)


class NonCanonicalUleb128(BcsError):
    """Raised when deserializing a non-canonical ULEB128 encoding."""

    def __init__(self) -> None:
        super().__init__("Non-canonical ULEB128 encoding (trailing zero bytes)")


class Uleb128Overflow(BcsError):
    """Raised when a ULEB128 value exceeds the maximum allowed."""

    def __init__(self) -> None:
        super().__init__("ULEB128 value overflow (exceeds u32 max)")


class ExceededMaxLength(BcsError):
    """Raised when a sequence exceeds MAX_SEQUENCE_LENGTH."""

    def __init__(self, length: int) -> None:
        super().__init__(f"Sequence length {length} exceeds maximum allowed (2^31 - 1)")


class ExceededContainerDepth(BcsError):
    """Raised when container nesting exceeds MAX_CONTAINER_DEPTH."""

    def __init__(self, container: str = "") -> None:
        msg = "Exceeded maximum container depth (500)"
        if container:
            msg += f" while entering {container}"
        super().__init__(msg)


class RemainingInput(BcsError):
    """Raised when input remains after deserialization."""

    def __init__(self, remaining: int) -> None:
        super().__init__(f"Remaining input after deserialization: {remaining} bytes")


class NonCanonicalMap(BcsError):
    """Raised when map keys are not sorted or contain duplicates."""

    def __init__(self, reason: str = "keys not sorted or contain duplicates") -> None:
        super().__init__(f"Non-canonical map: {reason}")


class UnknownVariant(BcsError):
    """Raised when deserializing an unknown enum variant."""

    def __init__(self, index: int, max_index: int) -> None:
        super().__init__(f"Unknown enum variant index: {index} (max: {max_index})")


class NotSupported(BcsError):
    """Raised when attempting to serialize/deserialize an unsupported type."""

    def __init__(self, type_name: str) -> None:
        super().__init__(f"Type not supported: {type_name}")
