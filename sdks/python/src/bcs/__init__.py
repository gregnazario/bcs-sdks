"""Binary Canonical Serialization (BCS) for Python.

BCS is a deterministic binary serialization format that guarantees
canonical representation - every value has exactly one valid encoding.

This library provides two APIs:

1. Manual API (BcsSerializer, BcsDeserializer):
   Explicit control over serialization with individual methods for each type.

   >>> s = BcsSerializer()
   >>> s.write_u8(1)
   >>> s.write_u64(100)
   >>> s.write_string("hello")
   >>> data = s.to_bytes()

   >>> d = BcsDeserializer(data)
   >>> d.read_u8()
   1
   >>> d.read_u64()
   100
   >>> d.read_string()
   'hello'

2. High-level API (to_bytes, from_bytes) [coming soon]:
   Automatic serialization using dataclasses with the @bcs_struct decorator.

   @bcs_struct
   @dataclass
   class Transfer:
       sender: bytes
       recipient: bytes
       amount: int

   transfer = Transfer(sender=addr1, recipient=addr2, amount=1000)
   data = to_bytes(transfer)
   transfer2 = from_bytes(Transfer, data)
"""

from __future__ import annotations

__version__ = "1.0.0"

# ULEB128 utilities
from . import uleb128

# Manual API
from .deserializer import BcsDeserializer

# Errors
from .errors import (
    BcsError,
    ExceededContainerDepth,
    ExceededMaxLength,
    InvalidBoolean,
    InvalidOption,
    InvalidUtf8,
    NonCanonicalMap,
    NonCanonicalUleb128,
    NotSupported,
    RemainingInput,
    Uleb128Overflow,
    UnexpectedEof,
    UnknownVariant,
)
from .serializer import BcsSerializer

# Types and constants
from .types import (
    MAX_CONTAINER_DEPTH,
    MAX_SEQUENCE_LENGTH,
    U8_MAX,
    U16_MAX,
    U32_MAX,
    U64_MAX,
    U128_MAX,
    U256_MAX,
    bcs_struct,
)

__all__ = [
    # Version
    "__version__",
    # Manual API
    "BcsSerializer",
    "BcsDeserializer",
    # Errors
    "BcsError",
    "UnexpectedEof",
    "InvalidBoolean",
    "InvalidOption",
    "InvalidUtf8",
    "NonCanonicalUleb128",
    "Uleb128Overflow",
    "ExceededMaxLength",
    "ExceededContainerDepth",
    "RemainingInput",
    "NonCanonicalMap",
    "UnknownVariant",
    "NotSupported",
    # Types and constants
    "MAX_SEQUENCE_LENGTH",
    "MAX_CONTAINER_DEPTH",
    "U8_MAX",
    "U16_MAX",
    "U32_MAX",
    "U64_MAX",
    "U128_MAX",
    "U256_MAX",
    "bcs_struct",
    # ULEB128 utilities
    "uleb128",
]


# Convenience functions for common operations
def serialize_u8(value: int) -> bytes:
    """Serialize a u8 value."""
    return BcsSerializer().write_u8(value).to_bytes()


def serialize_u64(value: int) -> bytes:
    """Serialize a u64 value."""
    return BcsSerializer().write_u64(value).to_bytes()


def serialize_string(value: str) -> bytes:
    """Serialize a string value."""
    return BcsSerializer().write_string(value).to_bytes()


def serialize_bytes(value: bytes) -> bytes:
    """Serialize a bytes value."""
    return BcsSerializer().write_bytes(value).to_bytes()


def deserialize_u8(data: bytes) -> int:
    """Deserialize a u8 value."""
    d = BcsDeserializer(data)
    value = d.read_u8()
    d.check_end()
    return value


def deserialize_u64(data: bytes) -> int:
    """Deserialize a u64 value."""
    d = BcsDeserializer(data)
    value = d.read_u64()
    d.check_end()
    return value


def deserialize_string(data: bytes) -> str:
    """Deserialize a string value."""
    d = BcsDeserializer(data)
    value = d.read_string()
    d.check_end()
    return value


def deserialize_bytes(data: bytes) -> bytes:
    """Deserialize a bytes value."""
    d = BcsDeserializer(data)
    value = d.read_bytes()
    d.check_end()
    return value
