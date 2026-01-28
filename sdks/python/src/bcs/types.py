"""BCS type definitions and constants."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, TypeVar

# Maximum sequence length (2^31 - 1)
MAX_SEQUENCE_LENGTH = (1 << 31) - 1

# Maximum container depth for nested structs/enums
MAX_CONTAINER_DEPTH = 500

# Integer type bounds
U8_MAX = 0xFF
U16_MAX = 0xFFFF
U32_MAX = 0xFFFFFFFF
U64_MAX = 0xFFFFFFFFFFFFFFFF
U128_MAX = (1 << 128) - 1
U256_MAX = (1 << 256) - 1

I8_MIN = -128
I8_MAX = 127
I16_MIN = -32768
I16_MAX = 32767
I32_MIN = -2147483648
I32_MAX = 2147483647
I64_MIN = -(1 << 63)
I64_MAX = (1 << 63) - 1
I128_MIN = -(1 << 127)
I128_MAX = (1 << 127) - 1
I256_MIN = -(1 << 255)
I256_MAX = (1 << 255) - 1

T = TypeVar("T")


@dataclass
class BcsStruct:
    """Base class for BCS-serializable structs.

    Subclass this and define fields in order to enable automatic serialization.

    Example:
        @dataclass
        class Transfer(BcsStruct):
            sender: bytes  # 32 bytes
            recipient: bytes  # 32 bytes
            amount: int  # u64
    """

    pass


@dataclass
class StructField:
    """Descriptor for a struct field with BCS serialization info."""

    name: str
    bcs_type: str
    index: int
    default: Any | None = None


def bcs_struct(cls: type[T]) -> type[T]:
    """Decorator to mark a dataclass as BCS-serializable.

    The decorator preserves field order for serialization.

    Example:
        @bcs_struct
        @dataclass
        class MyStruct:
            field1: int  # Will be serialized first
            field2: str  # Will be serialized second
    """
    # Store field order for serialization
    if hasattr(cls, "__dataclass_fields__"):
        cls._bcs_fields = list(cls.__dataclass_fields__.keys())  # type: ignore
    else:
        cls._bcs_fields = []  # type: ignore
    return cls


# Type aliases for clarity
U8 = int
U16 = int
U32 = int
U64 = int
U128 = int
U256 = int
I8 = int
I16 = int
I32 = int
I64 = int
I128 = int
I256 = int
Bool = bool
String = str
Bytes = bytes
AccountAddress = bytes  # 32 bytes


@dataclass
class TypeInfo:
    """Information about a BCS type for serialization."""

    name: str
    size: int | None  # None for variable-length types
    serialize: Callable[[Any], bytes] | None = None
    deserialize: Callable[[bytes, int], tuple[Any, int]] | None = None
