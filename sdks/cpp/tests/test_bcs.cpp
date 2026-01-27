// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <bcs/bcs.hpp>

#include <fstream>
#include <sstream>

#include "doctest.h"

// Simple JSON value type for test vector parsing
// (minimal implementation - just enough to parse our test vectors)
#include "json.hpp"
using json = nlohmann::json;

// Helper to convert hex string to bytes
std::vector<uint8_t> hex_to_bytes(const std::string& hex) {
    std::vector<uint8_t> bytes;
    for (size_t i = 0; i < hex.length(); i += 2) {
        bytes.push_back(
            static_cast<uint8_t>(std::stoi(hex.substr(i, 2), nullptr, 16)));
    }
    return bytes;
}

// Helper to convert bytes to hex string
std::string bytes_to_hex(const std::vector<uint8_t>& bytes) {
    std::stringstream ss;
    for (uint8_t b : bytes) {
        ss << std::hex << std::setfill('0') << std::setw(2)
           << static_cast<int>(b);
    }
    return ss.str();
}

// ============================================================================
// ULEB128 Tests
// ============================================================================

TEST_CASE("ULEB128 encoding") {
    SUBCASE("encode 0") {
        auto encoded = bcs::uleb128::encode(0);
        CHECK(encoded == std::vector<uint8_t>{0x00});
    }

    SUBCASE("encode 1") {
        auto encoded = bcs::uleb128::encode(1);
        CHECK(encoded == std::vector<uint8_t>{0x01});
    }

    SUBCASE("encode 127") {
        auto encoded = bcs::uleb128::encode(127);
        CHECK(encoded == std::vector<uint8_t>{0x7f});
    }

    SUBCASE("encode 128") {
        auto encoded = bcs::uleb128::encode(128);
        CHECK(encoded == std::vector<uint8_t>{0x80, 0x01});
    }

    SUBCASE("encode 255") {
        auto encoded = bcs::uleb128::encode(255);
        CHECK(encoded == std::vector<uint8_t>{0xff, 0x01});
    }

    SUBCASE("encode 300") {
        auto encoded = bcs::uleb128::encode(300);
        CHECK(encoded == std::vector<uint8_t>{0xac, 0x02});
    }

    SUBCASE("encode 16384") {
        auto encoded = bcs::uleb128::encode(16384);
        CHECK(encoded == std::vector<uint8_t>{0x80, 0x80, 0x01});
    }

    SUBCASE("encode u32 max") {
        auto encoded = bcs::uleb128::encode(0xFFFFFFFF);
        CHECK(encoded == std::vector<uint8_t>{0xff, 0xff, 0xff, 0xff, 0x0f});
    }
}

TEST_CASE("ULEB128 decoding") {
    SUBCASE("decode 0") {
        std::vector<uint8_t> data{0x00};
        auto [value, bytes_read] =
            bcs::uleb128::decode(data.data(), data.size());
        CHECK(value == 0);
        CHECK(bytes_read == 1);
    }

    SUBCASE("decode 127") {
        std::vector<uint8_t> data{0x7f};
        auto [value, bytes_read] =
            bcs::uleb128::decode(data.data(), data.size());
        CHECK(value == 127);
        CHECK(bytes_read == 1);
    }

    SUBCASE("decode 128") {
        std::vector<uint8_t> data{0x80, 0x01};
        auto [value, bytes_read] =
            bcs::uleb128::decode(data.data(), data.size());
        CHECK(value == 128);
        CHECK(bytes_read == 2);
    }

    SUBCASE("decode u32 max") {
        std::vector<uint8_t> data{0xff, 0xff, 0xff, 0xff, 0x0f};
        auto [value, bytes_read] =
            bcs::uleb128::decode(data.data(), data.size());
        CHECK(value == 0xFFFFFFFF);
        CHECK(bytes_read == 5);
    }

    SUBCASE("reject non-canonical encoding") {
        std::vector<uint8_t> data{0x80, 0x00};  // 0 with trailing zero
        CHECK_THROWS_AS(bcs::uleb128::decode(data.data(), data.size()),
                        bcs::Error);
    }

    SUBCASE("reject overflow") {
        std::vector<uint8_t> data{0xff, 0xff, 0xff, 0xff, 0x1f};  // > u32 max
        CHECK_THROWS_AS(bcs::uleb128::decode(data.data(), data.size()),
                        bcs::Error);
    }
}

// ============================================================================
// Boolean Tests
// ============================================================================

TEST_CASE("Boolean serialization") {
    SUBCASE("true") {
        auto bytes = bcs::serialize_bool(true);
        CHECK(bytes == std::vector<uint8_t>{0x01});
    }

    SUBCASE("false") {
        auto bytes = bcs::serialize_bool(false);
        CHECK(bytes == std::vector<uint8_t>{0x00});
    }
}

TEST_CASE("Boolean deserialization") {
    SUBCASE("true") {
        std::vector<uint8_t> data{0x01};
        CHECK(bcs::deserialize_bool(data) == true);
    }

    SUBCASE("false") {
        std::vector<uint8_t> data{0x00};
        CHECK(bcs::deserialize_bool(data) == false);
    }

    SUBCASE("invalid value") {
        std::vector<uint8_t> data{0x02};
        CHECK_THROWS_AS(bcs::deserialize_bool(data), bcs::Error);
    }
}

// ============================================================================
// Integer Tests
// ============================================================================

TEST_CASE("u8 serialization") {
    CHECK(bcs::serialize_u8(0) == std::vector<uint8_t>{0x00});
    CHECK(bcs::serialize_u8(255) == std::vector<uint8_t>{0xff});
    CHECK(bcs::serialize_u8(42) == std::vector<uint8_t>{0x2a});
}

TEST_CASE("u16 serialization (little-endian)") {
    CHECK(bcs::serialize_u16(0) == std::vector<uint8_t>{0x00, 0x00});
    CHECK(bcs::serialize_u16(0x1234) == std::vector<uint8_t>{0x34, 0x12});
    CHECK(bcs::serialize_u16(0xFFFF) == std::vector<uint8_t>{0xff, 0xff});
}

TEST_CASE("u32 serialization (little-endian)") {
    CHECK(bcs::serialize_u32(0) ==
          std::vector<uint8_t>{0x00, 0x00, 0x00, 0x00});
    CHECK(bcs::serialize_u32(0x12345678) ==
          std::vector<uint8_t>{0x78, 0x56, 0x34, 0x12});
}

TEST_CASE("u64 serialization (little-endian)") {
    CHECK(bcs::serialize_u64(0) ==
          std::vector<uint8_t>{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00});
    CHECK(bcs::serialize_u64(0x123456789ABCDEF0ULL) ==
          std::vector<uint8_t>{0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12});
}

TEST_CASE("i8 serialization (two's complement)") {
    bcs::Serializer ser;
    ser.write_i8(-1);
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0xff});

    ser.clear();
    ser.write_i8(-128);
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0x80});

    ser.clear();
    ser.write_i8(127);
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0x7f});
}

TEST_CASE("i16 serialization (two's complement, little-endian)") {
    bcs::Serializer ser;
    ser.write_i16(-1);
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0xff, 0xff});

    ser.clear();
    ser.write_i16(-32768);
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0x00, 0x80});
}

TEST_CASE("i32 serialization (two's complement, little-endian)") {
    bcs::Serializer ser;
    ser.write_i32(-1);
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0xff, 0xff, 0xff, 0xff});

    ser.clear();
    ser.write_i32(2147483647);  // max
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0xff, 0xff, 0xff, 0x7f});

    ser.clear();
    ser.write_i32(-2147483648);  // min
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0x00, 0x00, 0x00, 0x80});
}

TEST_CASE("i64 serialization (two's complement, little-endian)") {
    bcs::Serializer ser;
    ser.write_i64(-1);
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff});

    ser.clear();
    ser.write_i64(INT64_MAX);  // max
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f});

    ser.clear();
    ser.write_i64(INT64_MIN);  // min
    CHECK(ser.to_bytes() == std::vector<uint8_t>{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80});
}

TEST_CASE("i128 serialization (two's complement, little-endian)") {
    // -1 in two's complement (all 0xff)
    bcs::i128 neg_one;
    for (auto& b : neg_one) b = 0xff;

    bcs::Serializer ser;
    ser.write_i128(neg_one);
    auto bytes = ser.to_bytes();

    CHECK(bytes.size() == 16);
    for (auto b : bytes) {
        CHECK(b == 0xff);
    }
}

TEST_CASE("Integer deserialization") {
    SUBCASE("u8") {
        std::vector<uint8_t> data{0x2a};
        CHECK(bcs::deserialize_u8(data) == 42);
    }

    SUBCASE("u16") {
        std::vector<uint8_t> data{0x34, 0x12};
        CHECK(bcs::deserialize_u16(data) == 0x1234);
    }

    SUBCASE("u32") {
        std::vector<uint8_t> data{0x78, 0x56, 0x34, 0x12};
        CHECK(bcs::deserialize_u32(data) == 0x12345678);
    }

    SUBCASE("u64") {
        std::vector<uint8_t> data{0xf0, 0xde, 0xbc, 0x9a,
                                  0x78, 0x56, 0x34, 0x12};
        CHECK(bcs::deserialize_u64(data) == 0x123456789ABCDEF0ULL);
    }

    SUBCASE("i8 negative") {
        std::vector<uint8_t> data{0xff};
        bcs::Deserializer des(data);
        CHECK(des.read_i8() == -1);
    }

    SUBCASE("i16 negative") {
        std::vector<uint8_t> data{0x00, 0x80};
        bcs::Deserializer des(data);
        CHECK(des.read_i16() == -32768);
    }

    SUBCASE("i32 negative") {
        std::vector<uint8_t> data{0xff, 0xff, 0xff, 0xff};
        bcs::Deserializer des(data);
        CHECK(des.read_i32() == -1);
    }

    SUBCASE("i32 min") {
        std::vector<uint8_t> data{0x00, 0x00, 0x00, 0x80};
        bcs::Deserializer des(data);
        CHECK(des.read_i32() == -2147483648);
    }

    SUBCASE("i64 negative") {
        std::vector<uint8_t> data{0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
        bcs::Deserializer des(data);
        CHECK(des.read_i64() == -1);
    }

    SUBCASE("i64 min") {
        std::vector<uint8_t> data{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80};
        bcs::Deserializer des(data);
        CHECK(des.read_i64() == INT64_MIN);
    }

    SUBCASE("i128 negative") {
        std::vector<uint8_t> data(16, 0xff);
        bcs::Deserializer des(data);
        auto result = des.read_i128();
        for (auto b : result) {
            CHECK(b == 0xff);
        }
    }
}

// ============================================================================
// u128/u256 Tests
// ============================================================================

TEST_CASE("u128 serialization") {
    bcs::u128 value = {};
    value[0] = 0x01;  // Little-endian, so first byte is LSB

    bcs::Serializer ser;
    ser.write_u128(value);
    auto bytes = ser.to_bytes();

    CHECK(bytes.size() == 16);
    CHECK(bytes[0] == 0x01);
    for (size_t i = 1; i < 16; ++i) {
        CHECK(bytes[i] == 0x00);
    }
}

TEST_CASE("u256 serialization") {
    bcs::u256 value = {};
    value[0] = 0xff;
    value[31] = 0x01;

    bcs::Serializer ser;
    ser.write_u256(value);
    auto bytes = ser.to_bytes();

    CHECK(bytes.size() == 32);
    CHECK(bytes[0] == 0xff);
    CHECK(bytes[31] == 0x01);
}

// ============================================================================
// String Tests
// ============================================================================

TEST_CASE("String serialization") {
    SUBCASE("empty string") {
        auto bytes = bcs::serialize_string("");
        CHECK(bytes == std::vector<uint8_t>{0x00});
    }

    SUBCASE("hello") {
        auto bytes = bcs::serialize_string("hello");
        CHECK(bytes == std::vector<uint8_t>{0x05, 'h', 'e', 'l', 'l', 'o'});
    }

    SUBCASE("UTF-8 string") {
        auto bytes = bcs::serialize_string("café");
        // "café" is 5 bytes in UTF-8: c, a, f, 0xc3, 0xa9
        CHECK(bytes.size() == 6);
        CHECK(bytes[0] == 5);  // Length
    }
}

TEST_CASE("String deserialization") {
    SUBCASE("empty string") {
        std::vector<uint8_t> data{0x00};
        CHECK(bcs::deserialize_string(data) == "");
    }

    SUBCASE("hello") {
        std::vector<uint8_t> data{0x05, 'h', 'e', 'l', 'l', 'o'};
        CHECK(bcs::deserialize_string(data) == "hello");
    }

    SUBCASE("invalid UTF-8") {
        std::vector<uint8_t> data{0x02, 0xff, 0xfe};  // Invalid UTF-8 bytes
        CHECK_THROWS_AS(bcs::deserialize_string(data), bcs::Error);
    }
}

// ============================================================================
// Bytes Tests
// ============================================================================

TEST_CASE("Bytes serialization") {
    bcs::Serializer ser;
    std::vector<uint8_t> input{0x01, 0x02, 0x03};
    ser.write_bytes(input);
    auto bytes = ser.to_bytes();

    CHECK(bytes == std::vector<uint8_t>{0x03, 0x01, 0x02, 0x03});
}

TEST_CASE("Bytes deserialization") {
    std::vector<uint8_t> data{0x03, 0x01, 0x02, 0x03};
    bcs::Deserializer des(data);
    auto bytes = des.read_bytes();

    CHECK(bytes == std::vector<uint8_t>{0x01, 0x02, 0x03});
}

// ============================================================================
// Option Tests
// ============================================================================

TEST_CASE("Option serialization") {
    SUBCASE("Some") {
        bcs::Serializer ser;
        std::optional<uint8_t> opt = 42;
        ser.write_option(opt,
                         [](bcs::Serializer& s, uint8_t v) { s.write_u8(v); });
        CHECK(ser.to_bytes() == std::vector<uint8_t>{0x01, 0x2a});
    }

    SUBCASE("None") {
        bcs::Serializer ser;
        std::optional<uint8_t> opt = std::nullopt;
        ser.write_option(opt,
                         [](bcs::Serializer& s, uint8_t v) { s.write_u8(v); });
        CHECK(ser.to_bytes() == std::vector<uint8_t>{0x00});
    }
}

TEST_CASE("Option deserialization") {
    SUBCASE("Some") {
        std::vector<uint8_t> data{0x01, 0x2a};
        bcs::Deserializer des(data);
        auto opt = des.read_option<uint8_t>(
            [](bcs::Deserializer& d) { return d.read_u8(); });
        CHECK(opt.has_value());
        CHECK(opt.value() == 42);
    }

    SUBCASE("None") {
        std::vector<uint8_t> data{0x00};
        bcs::Deserializer des(data);
        auto opt = des.read_option<uint8_t>(
            [](bcs::Deserializer& d) { return d.read_u8(); });
        CHECK(!opt.has_value());
    }

    SUBCASE("Invalid tag") {
        std::vector<uint8_t> data{0x02};
        bcs::Deserializer des(data);
        CHECK_THROWS_AS(des.read_option<uint8_t>(
                            [](bcs::Deserializer& d) { return d.read_u8(); }),
                        bcs::Error);
    }
}

// ============================================================================
// Vector Tests
// ============================================================================

TEST_CASE("Vector serialization") {
    SUBCASE("empty vector") {
        bcs::Serializer ser;
        std::vector<uint8_t> vec;
        ser.write_vector(vec,
                         [](bcs::Serializer& s, uint8_t v) { s.write_u8(v); });
        CHECK(ser.to_bytes() == std::vector<uint8_t>{0x00});
    }

    SUBCASE("u8 vector") {
        bcs::Serializer ser;
        std::vector<uint8_t> vec{1, 2, 3};
        ser.write_vector(vec,
                         [](bcs::Serializer& s, uint8_t v) { s.write_u8(v); });
        CHECK(ser.to_bytes() == std::vector<uint8_t>{0x03, 0x01, 0x02, 0x03});
    }

    SUBCASE("u16 vector") {
        bcs::Serializer ser;
        std::vector<uint16_t> vec{1, 2, 3};
        ser.write_vector(
            vec, [](bcs::Serializer& s, uint16_t v) { s.write_u16(v); });
        CHECK(ser.to_bytes() ==
              std::vector<uint8_t>{0x03, 0x01, 0x00, 0x02, 0x00, 0x03, 0x00});
    }
}

TEST_CASE("Vector deserialization") {
    SUBCASE("empty vector") {
        std::vector<uint8_t> data{0x00};
        bcs::Deserializer des(data);
        auto vec = des.read_vector<uint8_t>(
            [](bcs::Deserializer& d) { return d.read_u8(); });
        CHECK(vec.empty());
    }

    SUBCASE("u8 vector") {
        std::vector<uint8_t> data{0x03, 0x01, 0x02, 0x03};
        bcs::Deserializer des(data);
        auto vec = des.read_vector<uint8_t>(
            [](bcs::Deserializer& d) { return d.read_u8(); });
        CHECK(vec == std::vector<uint8_t>{1, 2, 3});
    }
}

// ============================================================================
// Map Tests
// ============================================================================

TEST_CASE("Map serialization") {
    bcs::Serializer ser;
    std::map<uint8_t, uint8_t> map{{1, 10}, {2, 20}, {3, 30}};
    ser.write_map(
        map, [](bcs::Serializer& s, uint8_t k) { s.write_u8(k); },
        [](bcs::Serializer& s, uint8_t v) { s.write_u8(v); });

    // Map should be sorted by key (which it already is for std::map)
    CHECK(ser.to_bytes() ==
          std::vector<uint8_t>{0x03, 0x01, 0x0a, 0x02, 0x14, 0x03, 0x1e});
}

TEST_CASE("Map deserialization") {
    SUBCASE("valid map") {
        // 3 entries: (1, 10), (2, 20), (3, 30)
        std::vector<uint8_t> data{0x03, 0x01, 0x0a, 0x02, 0x14, 0x03, 0x1e};
        bcs::Deserializer des(data);
        auto map = des.read_map<uint8_t, uint8_t>(
            [](bcs::Deserializer& d) { return d.read_u8(); },
            [](bcs::Deserializer& d) { return d.read_u8(); });

        CHECK(map.size() == 3);
        CHECK(map[1] == 10);
        CHECK(map[2] == 20);
        CHECK(map[3] == 30);
    }

    SUBCASE("non-canonical map (wrong order)") {
        // Keys out of order: 2, 1
        std::vector<uint8_t> data{0x02, 0x02, 0x14, 0x01, 0x0a};
        bcs::Deserializer des(data);
        bool threw = false;
        try {
            (void)des.read_map<uint8_t, uint8_t>(
                [](bcs::Deserializer& d) { return d.read_u8(); },
                [](bcs::Deserializer& d) { return d.read_u8(); });
        } catch (const bcs::Error&) {
            threw = true;
        }
        CHECK(threw);
    }

    SUBCASE("duplicate keys") {
        // Duplicate key: 1, 1
        std::vector<uint8_t> data{0x02, 0x01, 0x0a, 0x01, 0x14};
        bcs::Deserializer des(data);
        bool threw = false;
        try {
            (void)des.read_map<uint8_t, uint8_t>(
                [](bcs::Deserializer& d) { return d.read_u8(); },
                [](bcs::Deserializer& d) { return d.read_u8(); });
        } catch (const bcs::Error&) {
            threw = true;
        }
        CHECK(threw);
    }
}

// ============================================================================
// Error Handling Tests
// ============================================================================

TEST_CASE("Error handling") {
    SUBCASE("unexpected EOF") {
        std::vector<uint8_t> data{0x01};  // Only 1 byte, need 2 for u16
        bcs::Deserializer des(data);
        CHECK_THROWS_AS(des.read_u16(), bcs::Error);
    }

    SUBCASE("remaining input") {
        std::vector<uint8_t> data{0x01, 0x02};  // Extra byte
        bcs::Deserializer des(data);
        des.read_u8();
        CHECK_THROWS_AS(des.check_end(), bcs::Error);
    }
}

// ============================================================================
// Round-trip Tests
// ============================================================================

TEST_CASE("Round-trip serialization") {
    SUBCASE("u64") {
        uint64_t original = 0x123456789ABCDEF0ULL;
        auto bytes = bcs::serialize_u64(original);
        auto result = bcs::deserialize_u64(bytes);
        CHECK(result == original);
    }

    SUBCASE("string") {
        std::string original = "Hello, BCS! 你好世界";
        auto bytes = bcs::serialize_string(original);
        auto result = bcs::deserialize_string(bytes);
        CHECK(result == original);
    }

    SUBCASE("complex structure") {
        // Serialize: (u8, string, vector<u16>)
        bcs::Serializer ser;
        ser.write_u8(42);
        ser.write_string(std::string("test"));
        std::vector<uint16_t> vec{100, 200, 300};
        ser.write_vector(
            vec, [](bcs::Serializer& s, uint16_t v) { s.write_u16(v); });
        auto bytes = ser.to_bytes();

        // Deserialize
        bcs::Deserializer des(bytes);
        CHECK(des.read_u8() == 42);
        CHECK(des.read_string() == "test");
        auto result_vec = des.read_vector<uint16_t>(
            [](bcs::Deserializer& d) { return d.read_u16(); });
        CHECK(result_vec == vec);
        des.check_end();
    }
}

// ============================================================================
// Test Vector Tests (load from JSON file)
// ============================================================================

TEST_CASE("Test vectors from JSON" * doctest::skip(true)) {
    // This test is skipped by default - enable it when running with test
    // vectors
    std::ifstream file("../../test-vectors/bcs-comprehensive.json");
    if (!file.is_open()) {
        MESSAGE("Test vectors file not found, skipping");
        return;
    }

    json test_data = json::parse(file);

    SUBCASE("Boolean tests") {
        for (const auto& test : test_data["valid"]["boolean"]) {
            std::string name = test["name"];
            bool value = test["value"];
            auto expected = hex_to_bytes(test["expected"]);

            INFO("Test: " << name);
            auto actual = bcs::serialize_bool(value);
            CHECK(actual == expected);
            CHECK(bcs::deserialize_bool(actual) == value);
        }
    }

    SUBCASE("u8 tests") {
        for (const auto& test : test_data["valid"]["u8"]) {
            std::string name = test["name"];
            uint8_t value = test["value"];
            auto expected = hex_to_bytes(test["expected"]);

            INFO("Test: " << name);
            auto actual = bcs::serialize_u8(value);
            CHECK(actual == expected);
            CHECK(bcs::deserialize_u8(actual) == value);
        }
    }

    // Add more test vector sections as needed...
}
