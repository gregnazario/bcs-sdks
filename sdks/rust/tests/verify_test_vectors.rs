use bcs::to_bytes;

#[test]
fn verify_u64_test_vector() {
    let value: u64 = 0x123456789abcdef0;
    let serialized = to_bytes(&value).unwrap();
    let hex: String = serialized.iter().map(|b| format!("{:02x}", b)).collect();

    println!("u64 0x123456789abcdef0:");
    println!("  Value: {}", value);
    println!("  Serialized hex: {}", hex);
    println!("  Expected hex: f0debc9a78563412");
    println!("  Match: {}", hex == "f0debc9a78563412");

    assert_eq!(hex, "f0debc9a78563412");
    assert_eq!(value, 1311768467463790320);
}

#[test]
fn verify_string_test_vector() {
    let s = "Hello, 世界! 🌍";
    let serialized = to_bytes(&s).unwrap();
    let hex: String = serialized.iter().map(|b| format!("{:02x}", b)).collect();

    println!("String 'Hello, 世界! 🌍':");
    println!("  UTF-8 byte length: {}", s.as_bytes().len());
    println!("  Serialized hex: {}", hex);
    println!("  Expected hex: 1248656c6c6f2c20e4b896e7958c2120f09f8c8d");
    println!("  Length byte: {}", serialized[0]);
    println!("  Expected length byte: 18");
    println!("  Actual byte length: {}", s.as_bytes().len());

    // The hex matches but length byte is wrong
    assert_eq!(s.as_bytes().len(), 19);
    assert_eq!(serialized[0], 19); // ULEB128 encoding of 19
}
