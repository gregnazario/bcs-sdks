/**
 * @file test_bcs.c
 * @brief BCS test suite
 */

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "bcs/bcs.h"

#define TEST(name) static void test_##name(void)
#define RUN_TEST(name)             \
    do {                           \
        printf("  %s... ", #name); \
        test_##name();             \
        printf("OK\n");            \
    } while (0)

#define ASSERT_EQ(a, b) assert((a) == (b))
#define ASSERT_TRUE(x) assert((x))
#define ASSERT_FALSE(x) assert(!(x))
#define ASSERT_OK(err) assert((err) == BCS_OK)
#define ASSERT_ERR(err, expected) assert((err) == (expected))

/* ============================================================================
 * ULEB128 Tests
 * ============================================================================ */

TEST(uleb128_encode_zero) {
    uint8_t buf[5];
    size_t len = bcs_uleb128_encode(0, buf, sizeof(buf));
    ASSERT_EQ(len, 1);
    ASSERT_EQ(buf[0], 0x00);
}

TEST(uleb128_encode_127) {
    uint8_t buf[5];
    size_t len = bcs_uleb128_encode(127, buf, sizeof(buf));
    ASSERT_EQ(len, 1);
    ASSERT_EQ(buf[0], 0x7f);
}

TEST(uleb128_encode_128) {
    uint8_t buf[5];
    size_t len = bcs_uleb128_encode(128, buf, sizeof(buf));
    ASSERT_EQ(len, 2);
    ASSERT_EQ(buf[0], 0x80);
    ASSERT_EQ(buf[1], 0x01);
}

TEST(uleb128_encode_300) {
    uint8_t buf[5];
    size_t len = bcs_uleb128_encode(300, buf, sizeof(buf));
    ASSERT_EQ(len, 2);
    ASSERT_EQ(buf[0], 0xac);
    ASSERT_EQ(buf[1], 0x02);
}

TEST(uleb128_encode_u32_max) {
    uint8_t buf[5];
    size_t len = bcs_uleb128_encode(0xFFFFFFFF, buf, sizeof(buf));
    ASSERT_EQ(len, 5);
    ASSERT_EQ(buf[0], 0xff);
    ASSERT_EQ(buf[1], 0xff);
    ASSERT_EQ(buf[2], 0xff);
    ASSERT_EQ(buf[3], 0xff);
    ASSERT_EQ(buf[4], 0x0f);
}

TEST(uleb128_decode_zero) {
    uint8_t data[] = {0x00};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_OK(err);
    ASSERT_EQ(len, 1);
    ASSERT_EQ(value, 0);
}

TEST(uleb128_decode_128) {
    uint8_t data[] = {0x80, 0x01};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_OK(err);
    ASSERT_EQ(len, 2);
    ASSERT_EQ(value, 128);
}

TEST(uleb128_reject_non_canonical_2byte) {
    uint8_t data[] = {0x80, 0x00};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_EQ(len, 0);
    ASSERT_ERR(err, BCS_ERR_NON_CANONICAL_ULEB128);
}

TEST(uleb128_reject_non_canonical_3byte) {
    uint8_t data[] = {0x80, 0x80, 0x00};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_EQ(len, 0);
    ASSERT_ERR(err, BCS_ERR_NON_CANONICAL_ULEB128);
}

TEST(uleb128_reject_non_canonical_4byte) {
    uint8_t data[] = {0x80, 0x80, 0x80, 0x00};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_EQ(len, 0);
    ASSERT_ERR(err, BCS_ERR_NON_CANONICAL_ULEB128);
}

TEST(uleb128_reject_non_canonical_5byte) {
    /* 0x80 0x80 0x80 0x80 0x00 is non-canonical (could be encoded in 4 bytes) */
    uint8_t data[] = {0x80, 0x80, 0x80, 0x80, 0x00};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_EQ(len, 0);
    ASSERT_ERR(err, BCS_ERR_NON_CANONICAL_ULEB128);
}

TEST(uleb128_reject_overflow) {
    uint8_t data[] = {0xff, 0xff, 0xff, 0xff, 0x1f};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_EQ(len, 0);
    ASSERT_ERR(err, BCS_ERR_ULEB128_OVERFLOW);
}

TEST(uleb128_reject_overflow_5byte_too_large) {
    /* 5th byte >= 0x10 would overflow u32 */
    uint8_t data[] = {0x80, 0x80, 0x80, 0x80, 0x10};
    uint32_t value;
    bcs_error_t err;
    size_t len = bcs_uleb128_decode(data, sizeof(data), &value, &err);
    ASSERT_EQ(len, 0);
    ASSERT_ERR(err, BCS_ERR_ULEB128_OVERFLOW);
}

/* ============================================================================
 * Boolean Tests
 * ============================================================================ */

TEST(bool_serialize_true) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_bool(&ser, true));
    ASSERT_EQ(bcs_serializer_size(&ser), 1);
    ASSERT_EQ(buf[0], 0x01);
}

TEST(bool_serialize_false) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_bool(&ser, false));
    ASSERT_EQ(bcs_serializer_size(&ser), 1);
    ASSERT_EQ(buf[0], 0x00);
}

TEST(bool_deserialize) {
    uint8_t data[] = {0x01, 0x00};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    bool val;
    ASSERT_OK(bcs_read_bool(&des, &val));
    ASSERT_TRUE(val);
    ASSERT_OK(bcs_read_bool(&des, &val));
    ASSERT_FALSE(val);
}

TEST(bool_invalid_value) {
    uint8_t data[] = {0x02};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    bool val;
    ASSERT_ERR(bcs_read_bool(&des, &val), BCS_ERR_INVALID_BOOLEAN);
}

/* ============================================================================
 * Integer Tests
 * ============================================================================ */

TEST(u8_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_u8(&ser, 42));
    ASSERT_EQ(bcs_serializer_size(&ser), 1);
    ASSERT_EQ(buf[0], 42);
}

TEST(u16_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_u16(&ser, 0x1234));
    ASSERT_EQ(bcs_serializer_size(&ser), 2);
    ASSERT_EQ(buf[0], 0x34);
    ASSERT_EQ(buf[1], 0x12);
}

TEST(u32_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_u32(&ser, 0x12345678));
    ASSERT_EQ(bcs_serializer_size(&ser), 4);
    ASSERT_EQ(buf[0], 0x78);
    ASSERT_EQ(buf[1], 0x56);
    ASSERT_EQ(buf[2], 0x34);
    ASSERT_EQ(buf[3], 0x12);
}

TEST(u64_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_u64(&ser, 0x123456789ABCDEF0ULL));
    ASSERT_EQ(bcs_serializer_size(&ser), 8);
    ASSERT_EQ(buf[0], 0xf0);
    ASSERT_EQ(buf[1], 0xde);
    ASSERT_EQ(buf[2], 0xbc);
    ASSERT_EQ(buf[3], 0x9a);
    ASSERT_EQ(buf[4], 0x78);
    ASSERT_EQ(buf[5], 0x56);
    ASSERT_EQ(buf[6], 0x34);
    ASSERT_EQ(buf[7], 0x12);
}

TEST(i8_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_i8(&ser, -1));
    ASSERT_EQ(bcs_serializer_size(&ser), 1);
    ASSERT_EQ(buf[0], 0xff);
}

TEST(i16_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_i16(&ser, -32768));
    ASSERT_EQ(bcs_serializer_size(&ser), 2);
    ASSERT_EQ(buf[0], 0x00);
    ASSERT_EQ(buf[1], 0x80);
}

TEST(i32_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_i32(&ser, -1));
    ASSERT_EQ(bcs_serializer_size(&ser), 4);
    ASSERT_EQ(buf[0], 0xff);
    ASSERT_EQ(buf[1], 0xff);
    ASSERT_EQ(buf[2], 0xff);
    ASSERT_EQ(buf[3], 0xff);

    bcs_serializer_t ser2;
    uint8_t buf2[16];
    ASSERT_OK(bcs_serializer_init(&ser2, buf2, sizeof(buf2)));
    ASSERT_OK(bcs_write_i32(&ser2, -2147483648));
    ASSERT_EQ(buf2[0], 0x00);
    ASSERT_EQ(buf2[1], 0x00);
    ASSERT_EQ(buf2[2], 0x00);
    ASSERT_EQ(buf2[3], 0x80);
}

TEST(i64_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_i64(&ser, -1));
    ASSERT_EQ(bcs_serializer_size(&ser), 8);
    for (int i = 0; i < 8; i++) {
        ASSERT_EQ(buf[i], 0xff);
    }

    bcs_serializer_t ser2;
    uint8_t buf2[16];
    ASSERT_OK(bcs_serializer_init(&ser2, buf2, sizeof(buf2)));
    ASSERT_OK(bcs_write_i64(&ser2, INT64_MIN));
    ASSERT_EQ(buf2[0], 0x00);
    ASSERT_EQ(buf2[7], 0x80);
}

TEST(u128_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[32];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));

    uint8_t value[16] = {0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    ASSERT_OK(bcs_write_u128(&ser, value));
    ASSERT_EQ(bcs_serializer_size(&ser), 16);
    ASSERT_EQ(buf[0], 0x01);
    for (int i = 1; i < 16; i++) {
        ASSERT_EQ(buf[i], 0x00);
    }
}

TEST(i128_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[32];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));

    // -1 in two's complement: all 0xff
    uint8_t neg_one[16];
    memset(neg_one, 0xff, 16);
    ASSERT_OK(bcs_write_i128(&ser, neg_one));
    ASSERT_EQ(bcs_serializer_size(&ser), 16);
    for (int i = 0; i < 16; i++) {
        ASSERT_EQ(buf[i], 0xff);
    }
}

TEST(integer_deserialize) {
    uint8_t data[] = {0x2a, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    uint8_t u8;
    ASSERT_OK(bcs_read_u8(&des, &u8));
    ASSERT_EQ(u8, 42);

    uint16_t u16;
    ASSERT_OK(bcs_read_u16(&des, &u16));
    ASSERT_EQ(u16, 0x1234);

    uint32_t u32;
    ASSERT_OK(bcs_read_u32(&des, &u32));
    ASSERT_EQ(u32, 0x12345678);
}

TEST(signed_integer_deserialize) {
    uint8_t data[] = {0xff, 0x00, 0x80};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    int8_t i8;
    ASSERT_OK(bcs_read_i8(&des, &i8));
    ASSERT_EQ(i8, -1);

    int16_t i16;
    ASSERT_OK(bcs_read_i16(&des, &i16));
    ASSERT_EQ(i16, -32768);
}

TEST(i32_deserialize) {
    uint8_t data1[] = {0xff, 0xff, 0xff, 0xff};
    bcs_deserializer_t des1;
    ASSERT_OK(bcs_deserializer_init(&des1, data1, sizeof(data1)));
    int32_t val1;
    ASSERT_OK(bcs_read_i32(&des1, &val1));
    ASSERT_EQ(val1, -1);

    uint8_t data2[] = {0x00, 0x00, 0x00, 0x80};
    bcs_deserializer_t des2;
    ASSERT_OK(bcs_deserializer_init(&des2, data2, sizeof(data2)));
    int32_t val2;
    ASSERT_OK(bcs_read_i32(&des2, &val2));
    ASSERT_EQ(val2, -2147483648);
}

TEST(i64_deserialize) {
    uint8_t data1[] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
    bcs_deserializer_t des1;
    ASSERT_OK(bcs_deserializer_init(&des1, data1, sizeof(data1)));
    int64_t val1;
    ASSERT_OK(bcs_read_i64(&des1, &val1));
    ASSERT_EQ(val1, -1);

    uint8_t data2[] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80};
    bcs_deserializer_t des2;
    ASSERT_OK(bcs_deserializer_init(&des2, data2, sizeof(data2)));
    int64_t val2;
    ASSERT_OK(bcs_read_i64(&des2, &val2));
    ASSERT_EQ(val2, INT64_MIN);
}

TEST(u128_deserialize) {
    uint8_t data[16] = {0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    uint8_t value[16];
    ASSERT_OK(bcs_read_u128(&des, value));
    ASSERT_EQ(value[0], 0x01);
    for (int i = 1; i < 16; i++) {
        ASSERT_EQ(value[i], 0x00);
    }
}

TEST(i128_deserialize) {
    uint8_t data[16];
    memset(data, 0xff, 16);
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    uint8_t value[16];
    ASSERT_OK(bcs_read_i128(&des, value));
    for (int i = 0; i < 16; i++) {
        ASSERT_EQ(value[i], 0xff);
    }
}

/* ============================================================================
 * String Tests
 * ============================================================================ */

TEST(string_serialize_empty) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_string(&ser, ""));
    ASSERT_EQ(bcs_serializer_size(&ser), 1);
    ASSERT_EQ(buf[0], 0x00);
}

TEST(string_serialize_hello) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_string(&ser, "hello"));
    ASSERT_EQ(bcs_serializer_size(&ser), 6);
    ASSERT_EQ(buf[0], 0x05);
    ASSERT_EQ(buf[1], 'h');
    ASSERT_EQ(buf[2], 'e');
    ASSERT_EQ(buf[3], 'l');
    ASSERT_EQ(buf[4], 'l');
    ASSERT_EQ(buf[5], 'o');
}

TEST(string_deserialize) {
    uint8_t data[] = {0x05, 'h', 'e', 'l', 'l', 'o'};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    char buf[32];
    size_t len;
    ASSERT_OK(bcs_read_string(&des, buf, sizeof(buf), &len));
    ASSERT_EQ(len, 5);
    ASSERT_EQ(strcmp(buf, "hello"), 0);
}

TEST(string_invalid_utf8_deserialize) {
    uint8_t data[] = {0x02, 0xff, 0xfe};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    char buf[32];
    size_t len;
    ASSERT_ERR(bcs_read_string(&des, buf, sizeof(buf), &len), BCS_ERR_INVALID_UTF8);
}

TEST(string_invalid_utf8_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));

    /* Invalid UTF-8: 0xff is never valid */
    char invalid[] = {(char)0xff, 0x00};
    ASSERT_ERR(bcs_write_string(&ser, invalid), BCS_ERR_INVALID_UTF8);
}

/* ============================================================================
 * Bytes Tests
 * ============================================================================ */

TEST(bytes_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));

    uint8_t data[] = {0x01, 0x02, 0x03};
    ASSERT_OK(bcs_write_bytes(&ser, data, 3));
    ASSERT_EQ(bcs_serializer_size(&ser), 4);
    ASSERT_EQ(buf[0], 0x03);
    ASSERT_EQ(buf[1], 0x01);
    ASSERT_EQ(buf[2], 0x02);
    ASSERT_EQ(buf[3], 0x03);
}

TEST(bytes_deserialize) {
    uint8_t data[] = {0x03, 0x01, 0x02, 0x03};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    uint8_t buf[16];
    size_t len;
    ASSERT_OK(bcs_read_bytes(&des, buf, sizeof(buf), &len));
    ASSERT_EQ(len, 3);
    ASSERT_EQ(buf[0], 0x01);
    ASSERT_EQ(buf[1], 0x02);
    ASSERT_EQ(buf[2], 0x03);
}

/* ============================================================================
 * Option Tests
 * ============================================================================ */

TEST(option_some_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_option_some(&ser));
    ASSERT_OK(bcs_write_u8(&ser, 42));
    ASSERT_EQ(bcs_serializer_size(&ser), 2);
    ASSERT_EQ(buf[0], 0x01);
    ASSERT_EQ(buf[1], 0x2a);
}

TEST(option_none_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_option_none(&ser));
    ASSERT_EQ(bcs_serializer_size(&ser), 1);
    ASSERT_EQ(buf[0], 0x00);
}

TEST(option_deserialize) {
    uint8_t data[] = {0x01, 0x2a, 0x00};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    bool is_some;
    ASSERT_OK(bcs_read_option_tag(&des, &is_some));
    ASSERT_TRUE(is_some);
    uint8_t val;
    ASSERT_OK(bcs_read_u8(&des, &val));
    ASSERT_EQ(val, 42);

    ASSERT_OK(bcs_read_option_tag(&des, &is_some));
    ASSERT_FALSE(is_some);
}

TEST(option_invalid_tag) {
    uint8_t data[] = {0x02};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    bool is_some;
    ASSERT_ERR(bcs_read_option_tag(&des, &is_some), BCS_ERR_INVALID_OPTION);
}

/* ============================================================================
 * Vector Tests
 * ============================================================================ */

TEST(vector_serialize) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_vector_len(&ser, 3));
    ASSERT_OK(bcs_write_u8(&ser, 1));
    ASSERT_OK(bcs_write_u8(&ser, 2));
    ASSERT_OK(bcs_write_u8(&ser, 3));
    ASSERT_EQ(bcs_serializer_size(&ser), 4);
    ASSERT_EQ(buf[0], 0x03);
    ASSERT_EQ(buf[1], 0x01);
    ASSERT_EQ(buf[2], 0x02);
    ASSERT_EQ(buf[3], 0x03);
}

TEST(vector_deserialize) {
    uint8_t data[] = {0x03, 0x01, 0x02, 0x03};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    size_t len;
    ASSERT_OK(bcs_read_vector_len(&des, &len));
    ASSERT_EQ(len, 3);

    for (size_t i = 0; i < len; i++) {
        uint8_t val;
        ASSERT_OK(bcs_read_u8(&des, &val));
        ASSERT_EQ(val, i + 1);
    }
}

/* ============================================================================
 * Error Handling Tests
 * ============================================================================ */

TEST(unexpected_eof) {
    uint8_t data[] = {0x01};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    uint16_t val;
    ASSERT_ERR(bcs_read_u16(&des, &val), BCS_ERR_UNEXPECTED_EOF);
}

TEST(remaining_input) {
    uint8_t data[] = {0x01, 0x02};
    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, data, sizeof(data)));

    uint8_t val;
    ASSERT_OK(bcs_read_u8(&des, &val));
    ASSERT_ERR(bcs_check_end(&des), BCS_ERR_REMAINING_INPUT);
}

/* ============================================================================
 * Round-trip Tests
 * ============================================================================ */

TEST(roundtrip_u64) {
    bcs_serializer_t ser;
    uint8_t buf[16];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_u64(&ser, 0x123456789ABCDEF0ULL));

    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, buf, bcs_serializer_size(&ser)));
    uint64_t val;
    ASSERT_OK(bcs_read_u64(&des, &val));
    ASSERT_EQ(val, 0x123456789ABCDEF0ULL);
}

TEST(roundtrip_string) {
    const char* original = "Hello, BCS!";

    bcs_serializer_t ser;
    uint8_t buf[64];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));
    ASSERT_OK(bcs_write_string(&ser, original));

    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, buf, bcs_serializer_size(&ser)));
    char str_buf[64];
    size_t len;
    ASSERT_OK(bcs_read_string(&des, str_buf, sizeof(str_buf), &len));
    ASSERT_EQ(strcmp(str_buf, original), 0);
}

TEST(roundtrip_complex) {
    bcs_serializer_t ser;
    uint8_t buf[128];
    ASSERT_OK(bcs_serializer_init(&ser, buf, sizeof(buf)));

    /* (u8, string, vector<u16>) */
    ASSERT_OK(bcs_write_u8(&ser, 42));
    ASSERT_OK(bcs_write_string(&ser, "test"));
    ASSERT_OK(bcs_write_vector_len(&ser, 3));
    ASSERT_OK(bcs_write_u16(&ser, 100));
    ASSERT_OK(bcs_write_u16(&ser, 200));
    ASSERT_OK(bcs_write_u16(&ser, 300));

    bcs_deserializer_t des;
    ASSERT_OK(bcs_deserializer_init(&des, buf, bcs_serializer_size(&ser)));

    uint8_t u8;
    ASSERT_OK(bcs_read_u8(&des, &u8));
    ASSERT_EQ(u8, 42);

    char str_buf[32];
    size_t str_len;
    ASSERT_OK(bcs_read_string(&des, str_buf, sizeof(str_buf), &str_len));
    ASSERT_EQ(strcmp(str_buf, "test"), 0);

    size_t vec_len;
    ASSERT_OK(bcs_read_vector_len(&des, &vec_len));
    ASSERT_EQ(vec_len, 3);

    uint16_t expected[] = {100, 200, 300};
    for (size_t i = 0; i < vec_len; i++) {
        uint16_t val;
        ASSERT_OK(bcs_read_u16(&des, &val));
        ASSERT_EQ(val, expected[i]);
    }

    ASSERT_OK(bcs_check_end(&des));
}

/* ============================================================================
 * Hex Utilities Tests
 * ============================================================================ */

TEST(bytes_to_hex) {
    uint8_t bytes[] = {0x01, 0x02, 0xab, 0xcd};
    char hex[16];
    size_t len = bcs_bytes_to_hex(bytes, 4, hex, sizeof(hex));
    ASSERT_EQ(len, 8);
    ASSERT_EQ(strcmp(hex, "0102abcd"), 0);
}

TEST(hex_to_bytes) {
    uint8_t bytes[16];
    size_t len = bcs_hex_to_bytes("0102abcd", bytes, sizeof(bytes));
    ASSERT_EQ(len, 4);
    ASSERT_EQ(bytes[0], 0x01);
    ASSERT_EQ(bytes[1], 0x02);
    ASSERT_EQ(bytes[2], 0xab);
    ASSERT_EQ(bytes[3], 0xcd);
}

/* ============================================================================
 * Dynamic Buffer Tests
 * ============================================================================ */

TEST(dynamic_buffer) {
    bcs_serializer_t ser;
    ASSERT_OK(bcs_serializer_init_dynamic(&ser, 4));

    /* Write more than initial capacity */
    for (int i = 0; i < 100; i++) {
        ASSERT_OK(bcs_write_u8(&ser, (uint8_t)i));
    }
    ASSERT_EQ(bcs_serializer_size(&ser), 100);

    /* Verify data */
    const uint8_t* data = bcs_serializer_bytes(&ser);
    for (int i = 0; i < 100; i++) {
        ASSERT_EQ(data[i], (uint8_t)i);
    }

    bcs_serializer_free(&ser);
}

/* ============================================================================
 * Main
 * ============================================================================ */

int main(void) {
    printf("Running BCS tests...\n\n");

    printf("ULEB128 tests:\n");
    RUN_TEST(uleb128_encode_zero);
    RUN_TEST(uleb128_encode_127);
    RUN_TEST(uleb128_encode_128);
    RUN_TEST(uleb128_encode_300);
    RUN_TEST(uleb128_encode_u32_max);
    RUN_TEST(uleb128_decode_zero);
    RUN_TEST(uleb128_decode_128);
    RUN_TEST(uleb128_reject_non_canonical_2byte);
    RUN_TEST(uleb128_reject_non_canonical_3byte);
    RUN_TEST(uleb128_reject_non_canonical_4byte);
    RUN_TEST(uleb128_reject_non_canonical_5byte);
    RUN_TEST(uleb128_reject_overflow);
    RUN_TEST(uleb128_reject_overflow_5byte_too_large);

    printf("\nBoolean tests:\n");
    RUN_TEST(bool_serialize_true);
    RUN_TEST(bool_serialize_false);
    RUN_TEST(bool_deserialize);
    RUN_TEST(bool_invalid_value);

    printf("\nInteger tests:\n");
    RUN_TEST(u8_serialize);
    RUN_TEST(u16_serialize);
    RUN_TEST(u32_serialize);
    RUN_TEST(u64_serialize);
    RUN_TEST(i8_serialize);
    RUN_TEST(i16_serialize);
    RUN_TEST(i32_serialize);
    RUN_TEST(i64_serialize);
    RUN_TEST(u128_serialize);
    RUN_TEST(i128_serialize);
    RUN_TEST(integer_deserialize);
    RUN_TEST(signed_integer_deserialize);
    RUN_TEST(i32_deserialize);
    RUN_TEST(i64_deserialize);
    RUN_TEST(u128_deserialize);
    RUN_TEST(i128_deserialize);

    printf("\nString tests:\n");
    RUN_TEST(string_serialize_empty);
    RUN_TEST(string_serialize_hello);
    RUN_TEST(string_deserialize);
    RUN_TEST(string_invalid_utf8_deserialize);
    RUN_TEST(string_invalid_utf8_serialize);

    printf("\nBytes tests:\n");
    RUN_TEST(bytes_serialize);
    RUN_TEST(bytes_deserialize);

    printf("\nOption tests:\n");
    RUN_TEST(option_some_serialize);
    RUN_TEST(option_none_serialize);
    RUN_TEST(option_deserialize);
    RUN_TEST(option_invalid_tag);

    printf("\nVector tests:\n");
    RUN_TEST(vector_serialize);
    RUN_TEST(vector_deserialize);

    printf("\nError handling tests:\n");
    RUN_TEST(unexpected_eof);
    RUN_TEST(remaining_input);

    printf("\nRound-trip tests:\n");
    RUN_TEST(roundtrip_u64);
    RUN_TEST(roundtrip_string);
    RUN_TEST(roundtrip_complex);

    printf("\nHex utilities tests:\n");
    RUN_TEST(bytes_to_hex);
    RUN_TEST(hex_to_bytes);

    printf("\nDynamic buffer tests:\n");
    RUN_TEST(dynamic_buffer);

    printf("\n========================================\n");
    printf("All tests passed!\n");

    return 0;
}
