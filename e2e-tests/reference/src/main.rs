//! Reference BCS test vector generator.
//!
//! This program generates test vectors by serializing various data types
//! using the reference Rust BCS implementation. These vectors are then used
//! to verify that all other language SDKs produce identical output.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// A single test case.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct TestCase {
    name: String,
    #[serde(rename = "type")]
    typ: String,
    value: serde_json::Value,
    bcs_hex: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    note: Option<String>,
}

/// Collection of test cases organized by category.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct TestVectors {
    version: String,
    description: String,
    primitives: Vec<TestCase>,
    strings: Vec<TestCase>,
    bytes: Vec<TestCase>,
    options: Vec<TestCase>,
    vectors: Vec<TestCase>,
    structs: Vec<TestCase>,
    complex: Vec<TestCase>,
}

fn to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

fn generate_primitive_tests() -> Vec<TestCase> {
    let mut cases = Vec::new();

    // Boolean tests
    cases.push(TestCase {
        name: "bool_false".to_string(),
        typ: "bool".to_string(),
        value: serde_json::json!(false),
        bcs_hex: to_hex(&bcs::to_bytes(&false).unwrap()),
        note: None,
    });
    cases.push(TestCase {
        name: "bool_true".to_string(),
        typ: "bool".to_string(),
        value: serde_json::json!(true),
        bcs_hex: to_hex(&bcs::to_bytes(&true).unwrap()),
        note: None,
    });

    // u8 tests
    for (name, value) in [
        ("u8_zero", 0u8),
        ("u8_one", 1u8),
        ("u8_mid", 127u8),
        ("u8_max", 255u8),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "u8".to_string(),
            value: serde_json::json!(value),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // u16 tests
    for (name, value) in [
        ("u16_zero", 0u16),
        ("u16_one", 1u16),
        ("u16_256", 256u16),
        ("u16_max", 65535u16),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "u16".to_string(),
            value: serde_json::json!(value),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // u32 tests
    for (name, value) in [
        ("u32_zero", 0u32),
        ("u32_one", 1u32),
        ("u32_0x12345678", 0x12345678u32),
        ("u32_max", u32::MAX),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "u32".to_string(),
            value: serde_json::json!(value),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // u64 tests (as strings for JSON compatibility)
    for (name, value) in [
        ("u64_zero", 0u64),
        ("u64_one", 1u64),
        ("u64_1_apt", 100_000_000u64),
        ("u64_large", 0x123456789abcdef0u64),
        ("u64_max", u64::MAX),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "u64".to_string(),
            value: serde_json::json!(value.to_string()),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // u128 tests
    for (name, value) in [
        ("u128_zero", 0u128),
        ("u128_one", 1u128),
        ("u128_u64_max", u64::MAX as u128),
        ("u128_u64_max_plus_one", (u64::MAX as u128) + 1),
        ("u128_max", u128::MAX),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "u128".to_string(),
            value: serde_json::json!(value.to_string()),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // i8 tests
    for (name, value) in [
        ("i8_zero", 0i8),
        ("i8_one", 1i8),
        ("i8_minus_one", -1i8),
        ("i8_max", i8::MAX),
        ("i8_min", i8::MIN),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "i8".to_string(),
            value: serde_json::json!(value),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // i16 tests
    for (name, value) in [
        ("i16_zero", 0i16),
        ("i16_minus_one", -1i16),
        ("i16_max", i16::MAX),
        ("i16_min", i16::MIN),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "i16".to_string(),
            value: serde_json::json!(value),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // i32 tests
    for (name, value) in [
        ("i32_zero", 0i32),
        ("i32_minus_one", -1i32),
        ("i32_max", i32::MAX),
        ("i32_min", i32::MIN),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "i32".to_string(),
            value: serde_json::json!(value),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // i64 tests
    for (name, value) in [
        ("i64_zero", 0i64),
        ("i64_minus_one", -1i64),
        ("i64_max", i64::MAX),
        ("i64_min", i64::MIN),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "i64".to_string(),
            value: serde_json::json!(value.to_string()),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    // i128 tests
    for (name, value) in [
        ("i128_zero", 0i128),
        ("i128_minus_one", -1i128),
        ("i128_max", i128::MAX),
        ("i128_min", i128::MIN),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "i128".to_string(),
            value: serde_json::json!(value.to_string()),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: None,
        });
    }

    cases
}

fn generate_string_tests() -> Vec<TestCase> {
    let mut cases = Vec::new();

    for (name, value, note) in [
        ("string_empty", "", None),
        ("string_hello", "hello", None),
        ("string_hello_world", "hello world", None),
        ("string_unicode_2byte", "héllo", Some("é is 2 UTF-8 bytes")),
        (
            "string_unicode_3byte",
            "日本語",
            Some("each char is 3 UTF-8 bytes"),
        ),
        ("string_emoji", "😀", Some("emoji is 4 UTF-8 bytes")),
        (
            "string_mixed_unicode",
            "Hello, 世界! 🌍",
            Some("mixed ASCII and Unicode"),
        ),
    ] {
        cases.push(TestCase {
            name: name.to_string(),
            typ: "string".to_string(),
            value: serde_json::json!(value),
            bcs_hex: to_hex(&bcs::to_bytes(&value).unwrap()),
            note: note.map(String::from),
        });
    }

    cases
}

fn generate_bytes_tests() -> Vec<TestCase> {
    let mut cases = Vec::new();

    cases.push(TestCase {
        name: "bytes_empty".to_string(),
        typ: "bytes".to_string(),
        value: serde_json::json!([]),
        bcs_hex: to_hex(&bcs::to_bytes(&Vec::<u8>::new()).unwrap()),
        note: None,
    });

    cases.push(TestCase {
        name: "bytes_single".to_string(),
        typ: "bytes".to_string(),
        value: serde_json::json!([42]),
        bcs_hex: to_hex(&bcs::to_bytes(&vec![42u8]).unwrap()),
        note: None,
    });

    cases.push(TestCase {
        name: "bytes_three".to_string(),
        typ: "bytes".to_string(),
        value: serde_json::json!([1, 2, 3]),
        bcs_hex: to_hex(&bcs::to_bytes(&vec![1u8, 2, 3]).unwrap()),
        note: None,
    });

    // 32-byte address (common in blockchain)
    let mut addr = [0u8; 32];
    addr[31] = 1;
    cases.push(TestCase {
        name: "bytes_address_0x1".to_string(),
        typ: "fixed_bytes_32".to_string(),
        value: serde_json::json!(addr.to_vec()),
        bcs_hex: to_hex(&bcs::to_bytes(&addr).unwrap()),
        note: Some("32-byte address 0x...01".to_string()),
    });

    cases
}

fn generate_option_tests() -> Vec<TestCase> {
    let mut cases = Vec::new();

    // None
    cases.push(TestCase {
        name: "option_none".to_string(),
        typ: "option<u64>".to_string(),
        value: serde_json::json!(null),
        bcs_hex: to_hex(&bcs::to_bytes(&Option::<u64>::None).unwrap()),
        note: None,
    });

    // Some(u8)
    cases.push(TestCase {
        name: "option_some_u8".to_string(),
        typ: "option<u8>".to_string(),
        value: serde_json::json!({"some": 42}),
        bcs_hex: to_hex(&bcs::to_bytes(&Some(42u8)).unwrap()),
        note: None,
    });

    // Some(u64)
    cases.push(TestCase {
        name: "option_some_u64".to_string(),
        typ: "option<u64>".to_string(),
        value: serde_json::json!({"some": "1000000"}),
        bcs_hex: to_hex(&bcs::to_bytes(&Some(1_000_000u64)).unwrap()),
        note: None,
    });

    // Some(bool)
    cases.push(TestCase {
        name: "option_some_bool_true".to_string(),
        typ: "option<bool>".to_string(),
        value: serde_json::json!({"some": true}),
        bcs_hex: to_hex(&bcs::to_bytes(&Some(true)).unwrap()),
        note: None,
    });

    // Some(string)
    cases.push(TestCase {
        name: "option_some_string".to_string(),
        typ: "option<string>".to_string(),
        value: serde_json::json!({"some": "hello"}),
        bcs_hex: to_hex(&bcs::to_bytes(&Some("hello")).unwrap()),
        note: None,
    });

    cases
}

fn generate_vector_tests() -> Vec<TestCase> {
    let mut cases = Vec::new();

    // Empty vector
    cases.push(TestCase {
        name: "vector_empty_u8".to_string(),
        typ: "vector<u8>".to_string(),
        value: serde_json::json!([]),
        bcs_hex: to_hex(&bcs::to_bytes(&Vec::<u8>::new()).unwrap()),
        note: None,
    });

    // Vector of u8
    cases.push(TestCase {
        name: "vector_u8".to_string(),
        typ: "vector<u8>".to_string(),
        value: serde_json::json!([1, 2, 3]),
        bcs_hex: to_hex(&bcs::to_bytes(&vec![1u8, 2, 3]).unwrap()),
        note: None,
    });

    // Vector of u64
    cases.push(TestCase {
        name: "vector_u64".to_string(),
        typ: "vector<u64>".to_string(),
        value: serde_json::json!(["1", "2", "3"]),
        bcs_hex: to_hex(&bcs::to_bytes(&vec![1u64, 2, 3]).unwrap()),
        note: None,
    });

    // Vector of bool
    cases.push(TestCase {
        name: "vector_bool".to_string(),
        typ: "vector<bool>".to_string(),
        value: serde_json::json!([true, false, true]),
        bcs_hex: to_hex(&bcs::to_bytes(&vec![true, false, true]).unwrap()),
        note: None,
    });

    // Nested vectors
    cases.push(TestCase {
        name: "vector_nested".to_string(),
        typ: "vector<vector<u8>>".to_string(),
        value: serde_json::json!([[1, 2], [3, 4]]),
        bcs_hex: to_hex(&bcs::to_bytes(&vec![vec![1u8, 2], vec![3u8, 4]]).unwrap()),
        note: Some("nested vectors".to_string()),
    });

    // Vector of strings
    cases.push(TestCase {
        name: "vector_strings".to_string(),
        typ: "vector<string>".to_string(),
        value: serde_json::json!(["hello", "world"]),
        bcs_hex: to_hex(&bcs::to_bytes(&vec!["hello", "world"]).unwrap()),
        note: None,
    });

    cases
}

/// Simple struct for testing
#[derive(Debug, Clone, Serialize, Deserialize)]
struct SimpleStruct {
    a: u8,
    b: u64,
}

/// Struct with string field
#[derive(Debug, Clone, Serialize, Deserialize)]
struct NamedValue {
    name: String,
    value: u64,
}

/// Transfer struct (common blockchain pattern)
#[derive(Debug, Clone, Serialize, Deserialize)]
struct Transfer {
    sender: [u8; 32],
    recipient: [u8; 32],
    amount: u64,
}

fn generate_struct_tests() -> Vec<TestCase> {
    let mut cases = Vec::new();

    // Simple struct
    let simple = SimpleStruct { a: 1, b: 100 };
    cases.push(TestCase {
        name: "struct_simple".to_string(),
        typ: "struct".to_string(),
        value: serde_json::json!({
            "fields": [
                {"name": "a", "type": "u8", "value": 1},
                {"name": "b", "type": "u64", "value": "100"}
            ]
        }),
        bcs_hex: to_hex(&bcs::to_bytes(&simple).unwrap()),
        note: Some("struct { a: u8, b: u64 }".to_string()),
    });

    // Struct with string
    let named = NamedValue {
        name: "test".to_string(),
        value: 42,
    };
    cases.push(TestCase {
        name: "struct_with_string".to_string(),
        typ: "struct".to_string(),
        value: serde_json::json!({
            "fields": [
                {"name": "name", "type": "string", "value": "test"},
                {"name": "value", "type": "u64", "value": "42"}
            ]
        }),
        bcs_hex: to_hex(&bcs::to_bytes(&named).unwrap()),
        note: Some("struct { name: string, value: u64 }".to_string()),
    });

    // Transfer struct
    let mut sender = [0u8; 32];
    sender[31] = 1;
    let mut recipient = [0u8; 32];
    recipient[31] = 2;
    let transfer = Transfer {
        sender,
        recipient,
        amount: 1_000_000,
    };
    cases.push(TestCase {
        name: "struct_transfer".to_string(),
        typ: "struct".to_string(),
        value: serde_json::json!({
            "fields": [
                {"name": "sender", "type": "fixed_bytes_32", "value": sender.to_vec()},
                {"name": "recipient", "type": "fixed_bytes_32", "value": recipient.to_vec()},
                {"name": "amount", "type": "u64", "value": "1000000"}
            ]
        }),
        bcs_hex: to_hex(&bcs::to_bytes(&transfer).unwrap()),
        note: Some("Transfer { sender: [u8;32], recipient: [u8;32], amount: u64 }".to_string()),
    });

    cases
}

fn generate_complex_tests() -> Vec<TestCase> {
    let mut cases = Vec::new();

    // Map<u8, u8>
    let mut map: BTreeMap<u8, u8> = BTreeMap::new();
    map.insert(1, 10);
    map.insert(2, 20);
    map.insert(3, 30);
    cases.push(TestCase {
        name: "map_u8_u8".to_string(),
        typ: "map<u8,u8>".to_string(),
        value: serde_json::json!({"1": 10, "2": 20, "3": 30}),
        bcs_hex: to_hex(&bcs::to_bytes(&map).unwrap()),
        note: Some("sorted by key bytes".to_string()),
    });

    // Map<string, u64>
    let mut string_map: BTreeMap<String, u64> = BTreeMap::new();
    string_map.insert("apple".to_string(), 1);
    string_map.insert("banana".to_string(), 2);
    string_map.insert("cherry".to_string(), 3);
    cases.push(TestCase {
        name: "map_string_u64".to_string(),
        typ: "map<string,u64>".to_string(),
        value: serde_json::json!({"apple": "1", "banana": "2", "cherry": "3"}),
        bcs_hex: to_hex(&bcs::to_bytes(&string_map).unwrap()),
        note: Some("sorted by BCS key bytes".to_string()),
    });

    // Tuple (pair)
    let tuple: (u8, u64) = (42, 1000);
    cases.push(TestCase {
        name: "tuple_u8_u64".to_string(),
        typ: "tuple<u8,u64>".to_string(),
        value: serde_json::json!([42, "1000"]),
        bcs_hex: to_hex(&bcs::to_bytes(&tuple).unwrap()),
        note: None,
    });

    // Option in vector
    let opt_vec: Vec<Option<u8>> = vec![Some(1), None, Some(3)];
    cases.push(TestCase {
        name: "vector_option".to_string(),
        typ: "vector<option<u8>>".to_string(),
        value: serde_json::json!([{"some": 1}, null, {"some": 3}]),
        bcs_hex: to_hex(&bcs::to_bytes(&opt_vec).unwrap()),
        note: None,
    });

    cases
}

fn main() {
    let vectors = TestVectors {
        version: "1.0.0".to_string(),
        description: "BCS e2e roundtrip test vectors generated by reference Rust implementation"
            .to_string(),
        primitives: generate_primitive_tests(),
        strings: generate_string_tests(),
        bytes: generate_bytes_tests(),
        options: generate_option_tests(),
        vectors: generate_vector_tests(),
        structs: generate_struct_tests(),
        complex: generate_complex_tests(),
    };

    let json = serde_json::to_string_pretty(&vectors).expect("Failed to serialize test vectors");
    println!("{}", json);
}
