#!/usr/bin/env python3
"""
Python BCS E2E Test Runner

Reads test vectors from stdin, performs roundtrip serialization,
and outputs results to stdout.
"""

import json
import sys
from pathlib import Path

# Add the SDK to path
sdk_path = Path(__file__).parent.parent.parent / "sdks" / "python" / "src"
sys.path.insert(0, str(sdk_path))

from bcs import BcsSerializer, BcsDeserializer


def hex_to_bytes(hex_str: str) -> bytes:
    """Convert hex string to bytes."""
    return bytes.fromhex(hex_str)


def bytes_to_hex(data: bytes) -> str:
    """Convert bytes to hex string."""
    return data.hex()


def roundtrip_bool(bcs_hex: str) -> str:
    """Roundtrip a boolean value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_bool()
    d.check_end()
    
    s = BcsSerializer()
    s.write_bool(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_u8(bcs_hex: str) -> str:
    """Roundtrip a u8 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_u8()
    d.check_end()
    
    s = BcsSerializer()
    s.write_u8(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_u16(bcs_hex: str) -> str:
    """Roundtrip a u16 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_u16()
    d.check_end()
    
    s = BcsSerializer()
    s.write_u16(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_u32(bcs_hex: str) -> str:
    """Roundtrip a u32 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_u32()
    d.check_end()
    
    s = BcsSerializer()
    s.write_u32(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_u64(bcs_hex: str) -> str:
    """Roundtrip a u64 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_u64()
    d.check_end()
    
    s = BcsSerializer()
    s.write_u64(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_u128(bcs_hex: str) -> str:
    """Roundtrip a u128 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_u128()
    d.check_end()
    
    s = BcsSerializer()
    s.write_u128(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_i8(bcs_hex: str) -> str:
    """Roundtrip an i8 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_i8()
    d.check_end()
    
    s = BcsSerializer()
    s.write_i8(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_i16(bcs_hex: str) -> str:
    """Roundtrip an i16 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_i16()
    d.check_end()
    
    s = BcsSerializer()
    s.write_i16(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_i32(bcs_hex: str) -> str:
    """Roundtrip an i32 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_i32()
    d.check_end()
    
    s = BcsSerializer()
    s.write_i32(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_i64(bcs_hex: str) -> str:
    """Roundtrip an i64 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_i64()
    d.check_end()
    
    s = BcsSerializer()
    s.write_i64(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_i128(bcs_hex: str) -> str:
    """Roundtrip an i128 value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_i128()
    d.check_end()
    
    s = BcsSerializer()
    s.write_i128(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_string(bcs_hex: str) -> str:
    """Roundtrip a string value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_string()
    d.check_end()
    
    s = BcsSerializer()
    s.write_string(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_bytes(bcs_hex: str) -> str:
    """Roundtrip a bytes value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_bytes()
    d.check_end()
    
    s = BcsSerializer()
    s.write_bytes(value)
    return bytes_to_hex(s.to_bytes())


def roundtrip_fixed_bytes(bcs_hex: str, length: int) -> str:
    """Roundtrip a fixed-length bytes value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    value = d.read_fixed_bytes(length)
    d.check_end()
    
    s = BcsSerializer()
    s.write_fixed_bytes(value, length)
    return bytes_to_hex(s.to_bytes())


def roundtrip_option_u8(bcs_hex: str) -> str:
    """Roundtrip an Option<u8> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    has_value = d.read_bool()
    if has_value:
        value = d.read_u8()
    else:
        value = None
    d.check_end()
    
    s = BcsSerializer()
    if value is not None:
        s.write_bool(True)
        s.write_u8(value)
    else:
        s.write_bool(False)
    return bytes_to_hex(s.to_bytes())


def roundtrip_option_u64(bcs_hex: str) -> str:
    """Roundtrip an Option<u64> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    has_value = d.read_bool()
    if has_value:
        value = d.read_u64()
    else:
        value = None
    d.check_end()
    
    s = BcsSerializer()
    if value is not None:
        s.write_bool(True)
        s.write_u64(value)
    else:
        s.write_bool(False)
    return bytes_to_hex(s.to_bytes())


def roundtrip_option_bool(bcs_hex: str) -> str:
    """Roundtrip an Option<bool> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    has_value = d.read_bool()
    if has_value:
        value = d.read_bool()
    else:
        value = None
    d.check_end()
    
    s = BcsSerializer()
    if value is not None:
        s.write_bool(True)
        s.write_bool(value)
    else:
        s.write_bool(False)
    return bytes_to_hex(s.to_bytes())


def roundtrip_option_string(bcs_hex: str) -> str:
    """Roundtrip an Option<string> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    has_value = d.read_bool()
    if has_value:
        value = d.read_string()
    else:
        value = None
    d.check_end()
    
    s = BcsSerializer()
    if value is not None:
        s.write_bool(True)
        s.write_string(value)
    else:
        s.write_bool(False)
    return bytes_to_hex(s.to_bytes())


def roundtrip_vector_u8(bcs_hex: str) -> str:
    """Roundtrip a Vec<u8> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    length = d.read_uleb128()
    values = [d.read_u8() for _ in range(length)]
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(values))
    for v in values:
        s.write_u8(v)
    return bytes_to_hex(s.to_bytes())


def roundtrip_vector_u64(bcs_hex: str) -> str:
    """Roundtrip a Vec<u64> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    length = d.read_uleb128()
    values = [d.read_u64() for _ in range(length)]
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(values))
    for v in values:
        s.write_u64(v)
    return bytes_to_hex(s.to_bytes())


def roundtrip_vector_bool(bcs_hex: str) -> str:
    """Roundtrip a Vec<bool> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    length = d.read_uleb128()
    values = [d.read_bool() for _ in range(length)]
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(values))
    for v in values:
        s.write_bool(v)
    return bytes_to_hex(s.to_bytes())


def roundtrip_vector_nested(bcs_hex: str) -> str:
    """Roundtrip a Vec<Vec<u8>> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    outer_length = d.read_uleb128()
    outer = []
    for _ in range(outer_length):
        inner_length = d.read_uleb128()
        inner = [d.read_u8() for _ in range(inner_length)]
        outer.append(inner)
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(outer))
    for inner in outer:
        s.write_uleb128(len(inner))
        for v in inner:
            s.write_u8(v)
    return bytes_to_hex(s.to_bytes())


def roundtrip_vector_strings(bcs_hex: str) -> str:
    """Roundtrip a Vec<String> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    length = d.read_uleb128()
    values = [d.read_string() for _ in range(length)]
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(values))
    for v in values:
        s.write_string(v)
    return bytes_to_hex(s.to_bytes())


def roundtrip_struct(bcs_hex: str, fields: list) -> str:
    """Roundtrip a struct value based on field definitions."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    
    values = []
    for field in fields:
        typ = field["type"]
        if typ == "u8":
            values.append(("u8", d.read_u8()))
        elif typ == "u64":
            values.append(("u64", d.read_u64()))
        elif typ == "string":
            values.append(("string", d.read_string()))
        elif typ == "fixed_bytes_32":
            values.append(("fixed_bytes_32", d.read_fixed_bytes(32)))
        else:
            raise ValueError(f"Unknown field type: {typ}")
    d.check_end()
    
    s = BcsSerializer()
    for typ, value in values:
        if typ == "u8":
            s.write_u8(value)
        elif typ == "u64":
            s.write_u64(value)
        elif typ == "string":
            s.write_string(value)
        elif typ == "fixed_bytes_32":
            s.write_fixed_bytes(value, 32)
    return bytes_to_hex(s.to_bytes())


def roundtrip_map_u8_u8(bcs_hex: str) -> str:
    """Roundtrip a Map<u8, u8> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    length = d.read_uleb128()
    pairs = [(d.read_u8(), d.read_u8()) for _ in range(length)]
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(pairs))
    for k, v in pairs:
        s.write_u8(k)
        s.write_u8(v)
    return bytes_to_hex(s.to_bytes())


def roundtrip_map_string_u64(bcs_hex: str) -> str:
    """Roundtrip a Map<String, u64> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    length = d.read_uleb128()
    pairs = [(d.read_string(), d.read_u64()) for _ in range(length)]
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(pairs))
    for k, v in pairs:
        s.write_string(k)
        s.write_u64(v)
    return bytes_to_hex(s.to_bytes())


def roundtrip_tuple_u8_u64(bcs_hex: str) -> str:
    """Roundtrip a (u8, u64) tuple."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    a = d.read_u8()
    b = d.read_u64()
    d.check_end()
    
    s = BcsSerializer()
    s.write_u8(a)
    s.write_u64(b)
    return bytes_to_hex(s.to_bytes())


def roundtrip_vector_option_u8(bcs_hex: str) -> str:
    """Roundtrip a Vec<Option<u8>> value."""
    data = hex_to_bytes(bcs_hex)
    d = BcsDeserializer(data)
    length = d.read_uleb128()
    values = []
    for _ in range(length):
        has_value = d.read_bool()
        if has_value:
            values.append(d.read_u8())
        else:
            values.append(None)
    d.check_end()
    
    s = BcsSerializer()
    s.write_uleb128(len(values))
    for v in values:
        if v is not None:
            s.write_bool(True)
            s.write_u8(v)
        else:
            s.write_bool(False)
    return bytes_to_hex(s.to_bytes())


def process_test_case(case: dict) -> dict:
    """Process a single test case and return the result."""
    name = case["name"]
    typ = case["type"]
    bcs_hex = case["bcs_hex"]
    
    try:
        if typ == "bool":
            result_hex = roundtrip_bool(bcs_hex)
        elif typ == "u8":
            result_hex = roundtrip_u8(bcs_hex)
        elif typ == "u16":
            result_hex = roundtrip_u16(bcs_hex)
        elif typ == "u32":
            result_hex = roundtrip_u32(bcs_hex)
        elif typ == "u64":
            result_hex = roundtrip_u64(bcs_hex)
        elif typ == "u128":
            result_hex = roundtrip_u128(bcs_hex)
        elif typ == "i8":
            result_hex = roundtrip_i8(bcs_hex)
        elif typ == "i16":
            result_hex = roundtrip_i16(bcs_hex)
        elif typ == "i32":
            result_hex = roundtrip_i32(bcs_hex)
        elif typ == "i64":
            result_hex = roundtrip_i64(bcs_hex)
        elif typ == "i128":
            result_hex = roundtrip_i128(bcs_hex)
        elif typ == "string":
            result_hex = roundtrip_string(bcs_hex)
        elif typ == "bytes":
            result_hex = roundtrip_bytes(bcs_hex)
        elif typ == "fixed_bytes_32":
            result_hex = roundtrip_fixed_bytes(bcs_hex, 32)
        elif typ == "option<u8>":
            result_hex = roundtrip_option_u8(bcs_hex)
        elif typ == "option<u64>":
            result_hex = roundtrip_option_u64(bcs_hex)
        elif typ == "option<bool>":
            result_hex = roundtrip_option_bool(bcs_hex)
        elif typ == "option<string>":
            result_hex = roundtrip_option_string(bcs_hex)
        elif typ == "vector<u8>":
            result_hex = roundtrip_vector_u8(bcs_hex)
        elif typ == "vector<u64>":
            result_hex = roundtrip_vector_u64(bcs_hex)
        elif typ == "vector<bool>":
            result_hex = roundtrip_vector_bool(bcs_hex)
        elif typ == "vector<vector<u8>>":
            result_hex = roundtrip_vector_nested(bcs_hex)
        elif typ == "vector<string>":
            result_hex = roundtrip_vector_strings(bcs_hex)
        elif typ == "struct":
            fields = case["value"]["fields"]
            result_hex = roundtrip_struct(bcs_hex, fields)
        elif typ == "map<u8,u8>":
            result_hex = roundtrip_map_u8_u8(bcs_hex)
        elif typ == "map<string,u64>":
            result_hex = roundtrip_map_string_u64(bcs_hex)
        elif typ == "tuple<u8,u64>":
            result_hex = roundtrip_tuple_u8_u64(bcs_hex)
        elif typ == "vector<option<u8>>":
            result_hex = roundtrip_vector_option_u8(bcs_hex)
        else:
            return {
                "name": name,
                "type": typ,
                "bcs_hex": "",
                "error": f"Unknown type: {typ}",
            }
        
        return {
            "name": name,
            "type": typ,
            "bcs_hex": result_hex,
        }
    except Exception as e:
        return {
            "name": name,
            "type": typ,
            "bcs_hex": "",
            "error": str(e),
        }


def main():
    # Read input from stdin
    input_data = sys.stdin.read()
    vectors = json.loads(input_data)
    
    # Process each category
    output = {
        "version": vectors.get("version", "1.0.0"),
        "description": f"Python roundtrip results",
        "primitives": [],
        "strings": [],
        "bytes": [],
        "options": [],
        "vectors": [],
        "structs": [],
        "complex": [],
    }
    
    for category in ["primitives", "strings", "bytes", "options", "vectors", "structs", "complex"]:
        for case in vectors.get(category, []):
            result = process_test_case(case)
            output[category].append(result)
    
    # Output JSON
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
