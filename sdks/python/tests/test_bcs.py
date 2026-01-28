"""BCS test suite using shared test vectors."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from bcs import (
    BcsDeserializer,
    BcsSerializer,
    InvalidBoolean,
    InvalidOption,
    InvalidUtf8,
    NonCanonicalMap,
    NonCanonicalUleb128,
    RemainingInput,
    Uleb128Overflow,
    UnexpectedEof,
    uleb128,
)

# Map error names from test vectors to exception classes
ERROR_MAP = {
    "InvalidBoolean": InvalidBoolean,
    "InvalidOption": InvalidOption,
    "InvalidUtf8": InvalidUtf8,
    "NonCanonicalMap": NonCanonicalMap,
    "NonCanonicalUleb128": NonCanonicalUleb128,
    "RemainingInput": RemainingInput,
    "Uleb128Overflow": Uleb128Overflow,
    "UnexpectedEof": UnexpectedEof,
}


# Load test vectors
def load_test_vectors() -> dict:
    """Load test vectors from shared JSON file."""
    vectors_path = os.environ.get("TEST_VECTORS", "../../test-vectors")
    json_path = Path(vectors_path) / "bcs-comprehensive.json"
    if not json_path.exists():
        pytest.skip(f"Test vectors not found at {json_path}")
    with open(json_path) as f:
        return json.load(f)


TEST_VECTORS = load_test_vectors()


def hex_to_bytes(hex_str: str) -> bytes:
    """Convert hex string to bytes."""
    return bytes.fromhex(hex_str)


# =============================================================================
# BOOLEAN TESTS
# =============================================================================


class TestBoolean:
    """Test boolean serialization/deserialization."""

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["bool"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_serialize_bool(self, test_case):
        """Test boolean serialization."""
        s = BcsSerializer()
        s.write_bool(test_case["value"])
        assert s.to_bytes() == hex_to_bytes(test_case["bcs_hex"])

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["bool"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_deserialize_bool(self, test_case):
        """Test boolean deserialization."""
        d = BcsDeserializer(hex_to_bytes(test_case["bcs_hex"]))
        assert d.read_bool() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["bool"]["invalid"],
        ids=lambda tc: tc["name"],
    )
    def test_deserialize_bool_invalid(self, test_case):
        """Test invalid boolean deserialization."""
        data = hex_to_bytes(test_case["bcs_hex"])
        d = BcsDeserializer(data)
        error_type = {
            "InvalidBoolean": InvalidBoolean,
            "UnexpectedEof": UnexpectedEof,
        }[test_case["error"]]
        with pytest.raises(error_type):
            d.read_bool()


# =============================================================================
# UNSIGNED INTEGER TESTS
# =============================================================================


class TestUnsignedIntegers:
    """Test unsigned integer serialization/deserialization."""

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["u8"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_u8(self, test_case):
        """Test u8 round-trip."""
        s = BcsSerializer()
        s.write_u8(test_case["value"])
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_u8() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["u16"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_u16(self, test_case):
        """Test u16 round-trip."""
        s = BcsSerializer()
        s.write_u16(test_case["value"])
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_u16() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["u32"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_u32(self, test_case):
        """Test u32 round-trip."""
        s = BcsSerializer()
        s.write_u32(test_case["value"])
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_u32() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["u64"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_u64(self, test_case):
        """Test u64 round-trip."""
        value = int(test_case["value"])
        s = BcsSerializer()
        s.write_u64(value)
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_u64() == value
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["u128"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_u128(self, test_case):
        """Test u128 round-trip."""
        value = int(test_case["value"])
        s = BcsSerializer()
        s.write_u128(value)
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_u128() == value
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["u256"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_u256(self, test_case):
        """Test u256 round-trip."""
        value = int(test_case["value"])
        s = BcsSerializer()
        s.write_u256(value)
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_u256() == value
        d.check_end()


# =============================================================================
# SIGNED INTEGER TESTS
# =============================================================================


class TestSignedIntegers:
    """Test signed integer serialization/deserialization."""

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["i8"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_i8(self, test_case):
        """Test i8 round-trip."""
        s = BcsSerializer()
        s.write_i8(test_case["value"])
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_i8() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["i16"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_i16(self, test_case):
        """Test i16 round-trip."""
        s = BcsSerializer()
        s.write_i16(test_case["value"])
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_i16() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["i32"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_i32(self, test_case):
        """Test i32 round-trip."""
        s = BcsSerializer()
        s.write_i32(test_case["value"])
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_i32() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["i64"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_i64(self, test_case):
        """Test i64 round-trip."""
        value = int(test_case["value"])
        s = BcsSerializer()
        s.write_i64(value)
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_i64() == value
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["i128"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_i128(self, test_case):
        """Test i128 round-trip."""
        value = int(test_case["value"])
        s = BcsSerializer()
        s.write_i128(value)
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_i128() == value
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["primitives"]["i256"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_i256(self, test_case):
        """Test i256 round-trip."""
        value = int(test_case["value"])
        s = BcsSerializer()
        s.write_i256(value)
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_i256() == value
        d.check_end()


# =============================================================================
# ULEB128 TESTS
# =============================================================================


class TestUleb128:
    """Test ULEB128 encoding/decoding."""

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["uleb128"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_encode(self, test_case):
        """Test ULEB128 encoding."""
        encoded = uleb128.encode(test_case["value"])
        assert encoded == hex_to_bytes(test_case["bcs_hex"])

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["uleb128"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_decode(self, test_case):
        """Test ULEB128 decoding."""
        data = hex_to_bytes(test_case["bcs_hex"])
        value, offset = uleb128.decode(data)
        assert value == test_case["value"]
        assert offset == len(data)

    @pytest.mark.parametrize(
        "test_case",
        [tc for tc in TEST_VECTORS["uleb128"]["invalid"] if tc["error"] == "NonCanonicalUleb128"],
        ids=lambda tc: tc["name"],
    )
    def test_decode_non_canonical(self, test_case):
        """Test rejection of non-canonical ULEB128."""
        data = hex_to_bytes(test_case["bcs_hex"])
        with pytest.raises(NonCanonicalUleb128):
            uleb128.decode(data)

    @pytest.mark.parametrize(
        "test_case",
        [tc for tc in TEST_VECTORS["uleb128"]["invalid"] if tc["error"] == "Uleb128Overflow"],
        ids=lambda tc: tc["name"],
    )
    def test_decode_overflow(self, test_case):
        """Test rejection of ULEB128 overflow."""
        data = hex_to_bytes(test_case["bcs_hex"])
        with pytest.raises(Uleb128Overflow):
            uleb128.decode(data)


# =============================================================================
# STRING TESTS
# =============================================================================


class TestStrings:
    """Test string serialization/deserialization."""

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["strings"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_string_roundtrip(self, test_case):
        """Test string round-trip."""
        s = BcsSerializer()
        s.write_string(test_case["value"])
        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

        d = BcsDeserializer(data)
        assert d.read_string() == test_case["value"]
        d.check_end()

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["strings"]["invalid"],
        ids=lambda tc: tc["name"],
    )
    def test_string_invalid_utf8(self, test_case):
        """Test rejection of invalid UTF-8."""
        data = hex_to_bytes(test_case["bcs_hex"])
        d = BcsDeserializer(data)
        expected_error = ERROR_MAP.get(test_case.get("error", "InvalidUtf8"), InvalidUtf8)
        with pytest.raises(expected_error):
            d.read_string()


# =============================================================================
# OPTION TESTS
# =============================================================================


class TestOption:
    """Test option serialization/deserialization."""

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["option"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_option_roundtrip(self, test_case):
        """Test option round-trip."""
        s = BcsSerializer()

        if test_case["value"] is None:
            s.write_option(None, lambda ser, v: None)
        else:
            inner_type = test_case.get("inner_type", "u8")
            inner_value = test_case["value"]["some"]
            if inner_type == "u8":
                s.write_option_u8(inner_value)
            elif inner_type == "u64":
                s.write_option_u64(int(inner_value))
            elif inner_type == "bool":
                s.write_option(inner_value, lambda ser, v: ser.write_bool(v))
            elif inner_type == "string":
                s.write_option_string(inner_value)

        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["option"]["invalid"],
        ids=lambda tc: tc["name"],
    )
    def test_option_invalid(self, test_case):
        """Test rejection of invalid option tags."""
        data = hex_to_bytes(test_case["bcs_hex"])
        d = BcsDeserializer(data)
        expected_error = ERROR_MAP.get(test_case.get("error", "InvalidOption"), InvalidOption)
        # Use appropriate reader based on inner_type
        inner_type = test_case.get("inner_type", "u8")
        with pytest.raises(expected_error):
            if inner_type == "u64":
                d.read_option_u64()
            else:
                d.read_option_u8()


# =============================================================================
# VECTOR TESTS
# =============================================================================


class TestVector:
    """Test vector serialization/deserialization."""

    @pytest.mark.parametrize(
        "test_case",
        TEST_VECTORS["vector"]["valid"],
        ids=lambda tc: tc["name"],
    )
    def test_vector_roundtrip(self, test_case):
        """Test vector round-trip."""
        inner_type = test_case.get("inner_type", "u8")
        values = test_case["value"]

        s = BcsSerializer()
        if inner_type == "u8":
            s.write_vector_u8(values)
        elif inner_type == "u64":
            s.write_vector_u64([int(v) for v in values])
        elif inner_type == "bool":
            s.write_vector(values, lambda ser, v: ser.write_bool(v))
        elif inner_type == "string":
            s.write_vector_string(values)
        elif inner_type == "vector<u8>":
            s.write_vector(values, lambda ser, v: ser.write_vector_u8(v))

        data = s.to_bytes()
        assert data == hex_to_bytes(test_case["bcs_hex"])


# =============================================================================
# MAP TESTS
# =============================================================================


class TestMap:
    """Test map serialization/deserialization."""

    def test_serialize_sorted_map(self):
        """Test map serialization with sorted keys."""
        s = BcsSerializer()
        # Map with keys 1, 2, 3
        items = {1: 10, 2: 20, 3: 30}
        s.write_map(items, lambda ser, k: ser.write_u8(k), lambda ser, v: ser.write_u8(v))
        # Length 3, then (1, 10), (2, 20), (3, 30)
        assert s.to_bytes() == bytes([3, 1, 10, 2, 20, 3, 30])

    def test_deserialize_valid_map(self):
        """Test map deserialization with sorted keys."""
        # Length 3, keys in sorted order: (1, 10), (2, 20), (3, 30)
        data = bytes([3, 1, 10, 2, 20, 3, 30])
        d = BcsDeserializer(data)
        result = d.read_map(lambda des: des.read_u8(), lambda des: des.read_u8())
        assert result == {1: 10, 2: 20, 3: 30}
        d.check_end()

    def test_reject_unsorted_keys(self):
        """Test rejection of unsorted map keys."""
        # Length 3, keys NOT sorted: (2, 20), (1, 10) - 2 > 1 is wrong order
        data = hex_to_bytes("0302140110")
        d = BcsDeserializer(data)
        with pytest.raises(NonCanonicalMap):
            d.read_map(lambda des: des.read_u8(), lambda des: des.read_u8())

    def test_reject_duplicate_keys(self):
        """Test rejection of duplicate map keys."""
        # Length 2, duplicate key 1: (1, 10), (1, 10)
        data = hex_to_bytes("0201100110")
        d = BcsDeserializer(data)
        with pytest.raises(NonCanonicalMap):
            d.read_map(lambda des: des.read_u8(), lambda des: des.read_u8())


# =============================================================================
# CONTAINER DEPTH TESTS
# =============================================================================


class TestContainerDepth:
    """Test container depth tracking."""

    def test_allows_up_to_500_nested_structs_serializer(self):
        """Test serializer allows up to 500 nested structs."""
        s = BcsSerializer()
        # Enter 500 nested structs (at max depth)
        for _ in range(500):
            s.enter_struct()
        # Should succeed - we're at depth 500

    def test_rejects_exceeding_500_nested_structs_serializer(self):
        """Test serializer rejects exceeding 500 nested structs."""
        from bcs.errors import ExceededContainerDepth

        s = BcsSerializer()
        # Enter 500 nested structs
        for _ in range(500):
            s.enter_struct()
        # 501st should fail
        with pytest.raises(ExceededContainerDepth):
            s.enter_struct()

    def test_rejects_exceeding_500_nested_structs_deserializer(self):
        """Test deserializer rejects exceeding 500 nested structs."""
        from bcs.errors import ExceededContainerDepth

        d = BcsDeserializer(b"")
        # Enter 500 nested structs
        for _ in range(500):
            d.enter_struct()
        # 501st should fail
        with pytest.raises(ExceededContainerDepth):
            d.enter_struct()

    def test_allows_up_to_500_nested_enums_serializer(self):
        """Test serializer allows up to 500 nested enums."""
        s = BcsSerializer()
        # Enter 500 nested enums (at max depth)
        for _ in range(500):
            s.write_variant_index(0)
        # Should succeed - we're at depth 500

    def test_rejects_exceeding_500_nested_enums_serializer(self):
        """Test serializer rejects exceeding 500 nested enums."""
        from bcs.errors import ExceededContainerDepth

        s = BcsSerializer()
        # Enter 500 nested enums
        for _ in range(500):
            s.write_variant_index(0)
        # 501st should fail
        with pytest.raises(ExceededContainerDepth):
            s.write_variant_index(0)


# =============================================================================
# ERROR CASE TESTS
# =============================================================================


class TestErrorCases:
    """Test error handling."""

    def test_remaining_input(self):
        """Test rejection of remaining input."""
        data = bytes([0x01, 0x00])  # true + extra byte
        d = BcsDeserializer(data)
        d.read_bool()
        with pytest.raises(RemainingInput):
            d.check_end()

    def test_unexpected_eof_u64(self):
        """Test unexpected EOF during u64 read."""
        data = bytes([0x01, 0x02, 0x03])  # Only 3 bytes
        d = BcsDeserializer(data)
        with pytest.raises(UnexpectedEof):
            d.read_u64()

    def test_empty_input(self):
        """Test unexpected EOF on empty input."""
        d = BcsDeserializer(b"")
        with pytest.raises(UnexpectedEof):
            d.read_u8()

    def test_write_vector_u8_validates_values(self):
        """Test that write_vector_u8 validates values in range."""
        s = BcsSerializer()
        # Valid values should work
        s.write_vector_u8([0, 127, 255])

        # Invalid value should raise
        s2 = BcsSerializer()
        with pytest.raises(ValueError, match="u8 value out of range"):
            s2.write_vector_u8([256])

        s3 = BcsSerializer()
        with pytest.raises(ValueError, match="u8 value out of range"):
            s3.write_vector_u8([-1])

    def test_max_alloc_limits_vector(self):
        """Test that max_alloc limits vector allocation."""
        from bcs import ExceededMaxLength

        # Create data with length prefix indicating 1000 elements
        # ULEB128 for 1000 = 0xe8 0x07
        data = bytes([0xE8, 0x07]) + bytes(1000)

        # Default should allow it
        d = BcsDeserializer(data)
        result = d.read_vector_u8()
        assert len(result) == 1000

        # With max_alloc=100, should reject
        d2 = BcsDeserializer(data, max_alloc=100)
        with pytest.raises(ExceededMaxLength):
            d2.read_vector_u8()

    def test_max_alloc_limits_string(self):
        """Test that max_alloc limits string allocation."""
        from bcs import ExceededMaxLength

        # Create a string with 100 bytes
        s = BcsSerializer()
        s.write_string("a" * 100)
        data = s.to_bytes()

        # Default should allow it
        d = BcsDeserializer(data)
        result = d.read_string()
        assert len(result) == 100

        # With max_alloc=50, should reject
        d2 = BcsDeserializer(data, max_alloc=50)
        with pytest.raises(ExceededMaxLength):
            d2.read_string()


# =============================================================================
# ROUND-TRIP TESTS
# =============================================================================


class TestRoundTrip:
    """Test serialization/deserialization round-trips."""

    def test_complex_struct(self):
        """Test a complex struct serialization."""
        s = BcsSerializer()
        s.enter_struct("Transfer")
        # sender (32 bytes)
        s.write_fixed_bytes(bytes(31) + bytes([1]), 32)
        # recipient (32 bytes)
        s.write_fixed_bytes(bytes(31) + bytes([2]), 32)
        # amount (u64)
        s.write_u64(1000000)
        s.leave_struct()
        data = s.to_bytes()

        d = BcsDeserializer(data)
        d.enter_struct("Transfer")
        sender = d.read_fixed_bytes(32)
        recipient = d.read_fixed_bytes(32)
        amount = d.read_u64()
        d.leave_struct()
        d.check_end()

        assert sender == bytes(31) + bytes([1])
        assert recipient == bytes(31) + bytes([2])
        assert amount == 1000000

    def test_nested_vectors(self):
        """Test nested vector serialization."""
        values = [[1, 2], [3, 4, 5]]
        s = BcsSerializer()
        s.write_vector(values, lambda ser, v: ser.write_vector_u8(v))
        data = s.to_bytes()

        d = BcsDeserializer(data)
        result = d.read_vector(lambda des: des.read_vector_u8())
        d.check_end()

        assert result == values
