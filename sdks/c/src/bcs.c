/**
 * @file bcs.c
 * @brief BCS implementation
 */

#include "bcs/bcs.h"

#include <stdlib.h>
#include <string.h>

/* ============================================================================
 * COMPILER HINTS
 * ============================================================================ */

#if defined(__GNUC__) || defined(__clang__)
#define BCS_LIKELY(x) __builtin_expect(!!(x), 1)
#define BCS_UNLIKELY(x) __builtin_expect(!!(x), 0)
#define BCS_ALWAYS_INLINE __attribute__((always_inline)) static inline
#define BCS_HOT __attribute__((hot))
#define BCS_PURE __attribute__((pure))
#else
#define BCS_LIKELY(x) (x)
#define BCS_UNLIKELY(x) (x)
#define BCS_ALWAYS_INLINE static inline
#define BCS_HOT
#define BCS_PURE
#endif

/* ============================================================================
 * ERROR MESSAGES
 * ============================================================================ */

const char* bcs_error_message(bcs_error_t err) {
    switch (err) {
        case BCS_OK:
            return "Success";
        case BCS_ERR_UNEXPECTED_EOF:
            return "Unexpected end of input";
        case BCS_ERR_INVALID_BOOLEAN:
            return "Invalid boolean value (expected 0 or 1)";
        case BCS_ERR_NON_CANONICAL_ULEB128:
            return "ULEB128 encoding is not canonical (has trailing zeros)";
        case BCS_ERR_ULEB128_OVERFLOW:
            return "ULEB128 value overflows u32";
        case BCS_ERR_EXCEEDED_MAX_LENGTH:
            return "Sequence length exceeds maximum";
        case BCS_ERR_EXCEEDED_CONTAINER_DEPTH:
            return "Container depth exceeds maximum";
        case BCS_ERR_INVALID_UTF8:
            return "Invalid UTF-8 encoding";
        case BCS_ERR_NON_CANONICAL_MAP:
            return "Map keys are not in sorted order";
        case BCS_ERR_DUPLICATE_MAP_KEY:
            return "Duplicate key in map";
        case BCS_ERR_INTEGER_OUT_OF_RANGE:
            return "Integer value out of range";
        case BCS_ERR_REMAINING_INPUT:
            return "Input has remaining bytes after deserialization";
        case BCS_ERR_INVALID_OPTION:
            return "Invalid option tag (expected 0 or 1)";
        case BCS_ERR_BUFFER_TOO_SMALL:
            return "Buffer too small";
        case BCS_ERR_NULL_POINTER:
            return "Null pointer provided";
        case BCS_ERR_ALLOCATION_FAILED:
            return "Memory allocation failed";
        default:
            return "Unknown error";
    }
}

/* ============================================================================
 * SERIALIZER - INTERNAL HELPERS
 * ============================================================================ */

/* Cold path for buffer growth - kept separate to keep hot path small */
static bcs_error_t grow_buffer(bcs_serializer_t* restrict ser, size_t required) {
    if (BCS_UNLIKELY(!ser->owns_buffer)) {
        return BCS_ERR_BUFFER_TOO_SMALL;
    }

    /* Check for overflow when doubling capacity */
    size_t new_capacity;
    if (ser->capacity > SIZE_MAX / 2) {
        /* Doubling would overflow, use required or max safe value */
        new_capacity = required;
    } else {
        new_capacity = ser->capacity * 2;
    }
    
    if (new_capacity < required) {
        new_capacity = required;
    }

    /* Limit allocation to MAX_SEQUENCE_LENGTH to prevent DoS */
    if (new_capacity > BCS_MAX_SEQUENCE_LENGTH) {
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    }

    uint8_t* new_buffer = (uint8_t*)realloc(ser->buffer, new_capacity);
    if (BCS_UNLIKELY(!new_buffer)) {
        return BCS_ERR_ALLOCATION_FAILED;
    }

    ser->buffer = new_buffer;
    ser->capacity = new_capacity;
    return BCS_OK;
}

BCS_ALWAYS_INLINE BCS_HOT bcs_error_t ensure_capacity(bcs_serializer_t* restrict ser,
                                                       size_t needed) {
    /* Check for overflow when calculating required size */
    if (BCS_UNLIKELY(needed > SIZE_MAX - ser->size)) {
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    }
    size_t required = ser->size + needed;
    if (BCS_LIKELY(required <= ser->capacity)) {
        return BCS_OK;
    }
    return grow_buffer(ser, required);
}

BCS_ALWAYS_INLINE BCS_HOT bcs_error_t write_byte(bcs_serializer_t* restrict ser,
                                                  uint8_t byte) {
    if (BCS_LIKELY(ser->size < ser->capacity)) {
        ser->buffer[ser->size++] = byte;
        return BCS_OK;
    }
    /* Check for overflow before calculating new size */
    if (BCS_UNLIKELY(ser->size == SIZE_MAX)) {
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    }
    bcs_error_t err = grow_buffer(ser, ser->size + 1);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;
    ser->buffer[ser->size++] = byte;
    return BCS_OK;
}

BCS_ALWAYS_INLINE BCS_HOT bcs_error_t write_bytes_raw(bcs_serializer_t* restrict ser,
                                                       const uint8_t* restrict data,
                                                       size_t len) {
    bcs_error_t err = ensure_capacity(ser, len);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;
    memcpy(ser->buffer + ser->size, data, len);
    ser->size += len;
    return BCS_OK;
}

/* ============================================================================
 * SERIALIZER
 * ============================================================================ */

bcs_error_t bcs_serializer_init(bcs_serializer_t* ser, uint8_t* buffer,
                                size_t capacity) {
    if (!ser || !buffer)
        return BCS_ERR_NULL_POINTER;
    ser->buffer = buffer;
    ser->capacity = capacity;
    ser->size = 0;
    ser->depth = 0;
    ser->owns_buffer = false;
    return BCS_OK;
}

bcs_error_t bcs_serializer_init_dynamic(bcs_serializer_t* ser,
                                        size_t initial_capacity) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    if (initial_capacity == 0)
        initial_capacity = 256;

    uint8_t* buffer = (uint8_t*)malloc(initial_capacity);
    if (!buffer)
        return BCS_ERR_ALLOCATION_FAILED;

    ser->buffer = buffer;
    ser->capacity = initial_capacity;
    ser->size = 0;
    ser->depth = 0;
    ser->owns_buffer = true;
    return BCS_OK;
}

void bcs_serializer_free(bcs_serializer_t* ser) {
    if (ser && ser->owns_buffer && ser->buffer) {
        free(ser->buffer);
        ser->buffer = NULL;
    }
}

void bcs_serializer_reset(bcs_serializer_t* ser) {
    if (ser) {
        ser->size = 0;
        ser->depth = 0;
    }
}

const uint8_t* bcs_serializer_bytes(const bcs_serializer_t* ser) {
    return ser ? ser->buffer : NULL;
}

size_t bcs_serializer_size(const bcs_serializer_t* ser) {
    return ser ? ser->size : 0;
}

BCS_HOT bcs_error_t bcs_write_bool(bcs_serializer_t* restrict ser, bool value) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, value ? 1 : 0);
}

BCS_HOT bcs_error_t bcs_write_u8(bcs_serializer_t* restrict ser, uint8_t value) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, value);
}

BCS_HOT bcs_error_t bcs_write_u16(bcs_serializer_t* restrict ser, uint16_t value) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    bcs_error_t err = ensure_capacity(ser, 2);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;
    uint8_t* p = ser->buffer + ser->size;
    p[0] = (uint8_t)(value);
    p[1] = (uint8_t)(value >> 8);
    ser->size += 2;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_write_u32(bcs_serializer_t* restrict ser, uint32_t value) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    bcs_error_t err = ensure_capacity(ser, 4);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;
    /* Unrolled loop - direct byte writes are faster than memcpy for small sizes */
    uint8_t* p = ser->buffer + ser->size;
    p[0] = (uint8_t)(value);
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
    ser->size += 4;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_write_u64(bcs_serializer_t* restrict ser, uint64_t value) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    bcs_error_t err = ensure_capacity(ser, 8);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;
    /* Unrolled loop for better performance */
    uint8_t* p = ser->buffer + ser->size;
    p[0] = (uint8_t)(value);
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
    p[4] = (uint8_t)(value >> 32);
    p[5] = (uint8_t)(value >> 40);
    p[6] = (uint8_t)(value >> 48);
    p[7] = (uint8_t)(value >> 56);
    ser->size += 8;
    return BCS_OK;
}

bcs_error_t bcs_write_u128(bcs_serializer_t* restrict ser, const uint8_t value[16]) {
    if (BCS_UNLIKELY(!ser || !value))
        return BCS_ERR_NULL_POINTER;
    return write_bytes_raw(ser, value, 16);
}

bcs_error_t bcs_write_u256(bcs_serializer_t* restrict ser, const uint8_t value[32]) {
    if (BCS_UNLIKELY(!ser || !value))
        return BCS_ERR_NULL_POINTER;
    return write_bytes_raw(ser, value, 32);
}

bcs_error_t bcs_write_i8(bcs_serializer_t* restrict ser, int8_t value) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, (uint8_t)value);
}

bcs_error_t bcs_write_i16(bcs_serializer_t* restrict ser, int16_t value) {
    return bcs_write_u16(ser, (uint16_t)value);
}

bcs_error_t bcs_write_i32(bcs_serializer_t* restrict ser, int32_t value) {
    return bcs_write_u32(ser, (uint32_t)value);
}

bcs_error_t bcs_write_i64(bcs_serializer_t* restrict ser, int64_t value) {
    return bcs_write_u64(ser, (uint64_t)value);
}

bcs_error_t bcs_write_i128(bcs_serializer_t* restrict ser, const uint8_t value[16]) {
    return bcs_write_u128(ser, value);
}

bcs_error_t bcs_write_i256(bcs_serializer_t* restrict ser, const uint8_t value[32]) {
    return bcs_write_u256(ser, value);
}

/* Optimized inline ULEB128 encode directly into serializer buffer */
BCS_HOT bcs_error_t bcs_write_uleb128(bcs_serializer_t* restrict ser, uint32_t value) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;

    /* Fast path: single byte (values 0-127, very common for lengths) */
    if (BCS_LIKELY(value < 0x80)) {
        return write_byte(ser, (uint8_t)value);
    }

    /* Ensure we have room for max ULEB128 bytes */
    bcs_error_t err = ensure_capacity(ser, BCS_ULEB128_MAX_BYTES);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;

    uint8_t* p = ser->buffer + ser->size;
    size_t i = 0;
    do {
        uint8_t byte = value & 0x7F;
        value >>= 7;
        if (value != 0) {
            byte |= 0x80;
        }
        p[i++] = byte;
    } while (value != 0);
    ser->size += i;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_write_fixed_bytes(bcs_serializer_t* restrict ser,
                                           const uint8_t* restrict data,
                                           size_t len) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(len > 0 && !data))
        return BCS_ERR_NULL_POINTER;
    return write_bytes_raw(ser, data, len);
}

BCS_HOT bcs_error_t bcs_write_bytes(bcs_serializer_t* restrict ser,
                                     const uint8_t* restrict data, size_t len) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(len > BCS_MAX_SEQUENCE_LENGTH))
        return BCS_ERR_EXCEEDED_MAX_LENGTH;

    /* Optimize: check capacity for length + data in one call */
    size_t uleb_size = bcs_uleb128_encoded_size((uint32_t)len);
    /* Check for overflow before addition */
    if (BCS_UNLIKELY(uleb_size > SIZE_MAX - len)) {
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    }
    bcs_error_t err = ensure_capacity(ser, uleb_size + len);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;

    /* Write ULEB128 length directly (capacity already ensured) */
    uint8_t* p = ser->buffer + ser->size;
    uint32_t v = (uint32_t)len;
    size_t i = 0;
    do {
        uint8_t byte = v & 0x7F;
        v >>= 7;
        if (v != 0) byte |= 0x80;
        p[i++] = byte;
    } while (v != 0);
    ser->size += i;

    /* Write data (capacity already ensured) */
    if (len > 0) {
        memcpy(ser->buffer + ser->size, data, len);
        ser->size += len;
    }
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_write_string(bcs_serializer_t* restrict ser,
                                      const char* restrict str) {
    if (BCS_UNLIKELY(!ser || !str))
        return BCS_ERR_NULL_POINTER;
    size_t len = strlen(str);
    /* Validate UTF-8 on write to prevent serializing invalid data */
    if (BCS_UNLIKELY(!bcs_is_valid_utf8((const uint8_t*)str, len)))
        return BCS_ERR_INVALID_UTF8;
    return bcs_write_bytes(ser, (const uint8_t*)str, len);
}

bcs_error_t bcs_write_string_n(bcs_serializer_t* restrict ser,
                               const char* restrict str, size_t len) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(len > 0 && !str))
        return BCS_ERR_NULL_POINTER;
    /* Validate UTF-8 on write to prevent serializing invalid data */
    if (BCS_UNLIKELY(len > 0 && !bcs_is_valid_utf8((const uint8_t*)str, len)))
        return BCS_ERR_INVALID_UTF8;
    return bcs_write_bytes(ser, (const uint8_t*)str, len);
}

bcs_error_t bcs_enter_struct(bcs_serializer_t* restrict ser) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(ser->depth >= BCS_MAX_CONTAINER_DEPTH)) {
        return BCS_ERR_EXCEEDED_CONTAINER_DEPTH;
    }
    ser->depth++;
    return BCS_OK;
}

bcs_error_t bcs_leave_struct(bcs_serializer_t* restrict ser) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    if (BCS_LIKELY(ser->depth > 0))
        ser->depth--;
    return BCS_OK;
}

bcs_error_t bcs_write_variant_index(bcs_serializer_t* restrict ser, uint32_t index) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(ser->depth >= BCS_MAX_CONTAINER_DEPTH)) {
        return BCS_ERR_EXCEEDED_CONTAINER_DEPTH;
    }
    ser->depth++;
    return bcs_write_uleb128(ser, index);
}

bcs_error_t bcs_leave_enum(bcs_serializer_t* restrict ser) {
    return bcs_leave_struct(ser);
}

bcs_error_t bcs_write_option_none(bcs_serializer_t* restrict ser) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, 0);
}

bcs_error_t bcs_write_option_some(bcs_serializer_t* restrict ser) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, 1);
}

BCS_HOT bcs_error_t bcs_write_vector_len(bcs_serializer_t* restrict ser, size_t len) {
    if (BCS_UNLIKELY(!ser))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(len > BCS_MAX_SEQUENCE_LENGTH))
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    return bcs_write_uleb128(ser, (uint32_t)len);
}

BCS_HOT bcs_error_t bcs_write_map_len(bcs_serializer_t* restrict ser, size_t len) {
    return bcs_write_vector_len(ser, len);
}

/* ============================================================================
 * DESERIALIZER
 * ============================================================================ */

bcs_error_t bcs_deserializer_init(bcs_deserializer_t* restrict des,
                                  const uint8_t* restrict data,
                                  size_t size) {
    if (BCS_UNLIKELY(!des))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(size > 0 && !data))
        return BCS_ERR_NULL_POINTER;

    des->data = data;
    des->size = size;
    des->offset = 0;
    des->depth = 0;
    return BCS_OK;
}

BCS_PURE bcs_error_t bcs_check_end(const bcs_deserializer_t* restrict des) {
    if (BCS_UNLIKELY(!des))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(des->offset < des->size))
        return BCS_ERR_REMAINING_INPUT;
    return BCS_OK;
}

BCS_PURE size_t bcs_remaining(const bcs_deserializer_t* restrict des) {
    if (BCS_UNLIKELY(!des))
        return 0;
    return des->size - des->offset;
}

BCS_HOT bcs_error_t bcs_read_bool(bcs_deserializer_t* restrict des, bool* restrict value) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->offset >= des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    uint8_t byte = des->data[des->offset++];
    if (BCS_LIKELY(byte == 0)) {
        *value = false;
    } else if (BCS_LIKELY(byte == 1)) {
        *value = true;
    } else {
        return BCS_ERR_INVALID_BOOLEAN;
    }
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_u8(bcs_deserializer_t* restrict des, uint8_t* restrict value) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->offset >= des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    *value = des->data[des->offset++];
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_u16(bcs_deserializer_t* restrict des, uint16_t* restrict value) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->offset + 2 > des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    const uint8_t* p = des->data + des->offset;
    *value = (uint16_t)p[0] | ((uint16_t)p[1] << 8);
    des->offset += 2;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_u32(bcs_deserializer_t* restrict des, uint32_t* restrict value) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->offset + 4 > des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    /* Unrolled for performance */
    const uint8_t* p = des->data + des->offset;
    *value = (uint32_t)p[0] |
             ((uint32_t)p[1] << 8) |
             ((uint32_t)p[2] << 16) |
             ((uint32_t)p[3] << 24);
    des->offset += 4;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_u64(bcs_deserializer_t* restrict des, uint64_t* restrict value) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->offset + 8 > des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    /* Unrolled for performance */
    const uint8_t* p = des->data + des->offset;
    *value = (uint64_t)p[0] |
             ((uint64_t)p[1] << 8) |
             ((uint64_t)p[2] << 16) |
             ((uint64_t)p[3] << 24) |
             ((uint64_t)p[4] << 32) |
             ((uint64_t)p[5] << 40) |
             ((uint64_t)p[6] << 48) |
             ((uint64_t)p[7] << 56);
    des->offset += 8;
    return BCS_OK;
}

bcs_error_t bcs_read_u128(bcs_deserializer_t* restrict des, uint8_t value[16]) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;
    return bcs_read_fixed_bytes(des, value, 16);
}

bcs_error_t bcs_read_u256(bcs_deserializer_t* restrict des, uint8_t value[32]) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;
    return bcs_read_fixed_bytes(des, value, 32);
}

bcs_error_t bcs_read_i8(bcs_deserializer_t* restrict des, int8_t* restrict value) {
    return bcs_read_u8(des, (uint8_t*)value);
}

bcs_error_t bcs_read_i16(bcs_deserializer_t* restrict des, int16_t* restrict value) {
    return bcs_read_u16(des, (uint16_t*)value);
}

bcs_error_t bcs_read_i32(bcs_deserializer_t* restrict des, int32_t* restrict value) {
    return bcs_read_u32(des, (uint32_t*)value);
}

bcs_error_t bcs_read_i64(bcs_deserializer_t* restrict des, int64_t* restrict value) {
    return bcs_read_u64(des, (uint64_t*)value);
}

bcs_error_t bcs_read_i128(bcs_deserializer_t* restrict des, uint8_t value[16]) {
    return bcs_read_u128(des, value);
}

bcs_error_t bcs_read_i256(bcs_deserializer_t* restrict des, uint8_t value[32]) {
    return bcs_read_u256(des, value);
}

/* Optimized inline ULEB128 decode */
BCS_HOT bcs_error_t bcs_read_uleb128(bcs_deserializer_t* restrict des,
                                      uint32_t* restrict value) {
    if (BCS_UNLIKELY(!des || !value))
        return BCS_ERR_NULL_POINTER;

    size_t remaining = des->size - des->offset;
    if (BCS_UNLIKELY(remaining == 0))
        return BCS_ERR_UNEXPECTED_EOF;

    const uint8_t* p = des->data + des->offset;

    /* Fast path: single byte (values 0-127, very common) */
    if (BCS_LIKELY((*p & 0x80) == 0)) {
        *value = *p;
        des->offset++;
        return BCS_OK;
    }

    /* Multi-byte path */
    uint64_t result = 0;
    unsigned shift = 0;
    size_t i = 0;
    size_t max_bytes = remaining < BCS_ULEB128_MAX_BYTES ? remaining : BCS_ULEB128_MAX_BYTES;

    for (; i < max_bytes; i++) {
        uint8_t byte = p[i];
        uint8_t digit = byte & 0x7F;
        result |= (uint64_t)digit << shift;

        if ((byte & 0x80) == 0) {
            /* Check for non-canonical encoding */
            if (BCS_UNLIKELY(shift > 0 && digit == 0)) {
                return BCS_ERR_NON_CANONICAL_ULEB128;
            }
            /* Check for overflow */
            if (BCS_UNLIKELY(result > 0xFFFFFFFF)) {
                return BCS_ERR_ULEB128_OVERFLOW;
            }
            *value = (uint32_t)result;
            des->offset += i + 1;
            return BCS_OK;
        }
        shift += 7;
    }

    if (i == BCS_ULEB128_MAX_BYTES) {
        return BCS_ERR_ULEB128_OVERFLOW;
    }
    return BCS_ERR_UNEXPECTED_EOF;
}

BCS_HOT bcs_error_t bcs_read_fixed_bytes(bcs_deserializer_t* restrict des,
                                          uint8_t* restrict buffer, size_t len) {
    if (BCS_UNLIKELY(!des))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(len > 0 && !buffer))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->offset + len > des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    memcpy(buffer, des->data + des->offset, len);
    des->offset += len;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_bytes_len(bcs_deserializer_t* restrict des,
                                        size_t* restrict len) {
    if (BCS_UNLIKELY(!des || !len))
        return BCS_ERR_NULL_POINTER;

    uint32_t uleb_len;
    bcs_error_t err = bcs_read_uleb128(des, &uleb_len);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;

    if (BCS_UNLIKELY(uleb_len > BCS_MAX_SEQUENCE_LENGTH)) {
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    }

    *len = uleb_len;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_bytes(bcs_deserializer_t* restrict des,
                                    uint8_t* restrict buffer, size_t buffer_size,
                                    size_t* restrict out_len) {
    if (BCS_UNLIKELY(!des || !out_len))
        return BCS_ERR_NULL_POINTER;

    size_t len;
    bcs_error_t err = bcs_read_bytes_len(des, &len);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;

    if (BCS_UNLIKELY(len > buffer_size))
        return BCS_ERR_BUFFER_TOO_SMALL;

    if (BCS_UNLIKELY(des->offset + len > des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    memcpy(buffer, des->data + des->offset, len);
    des->offset += len;
    *out_len = len;
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_string(bcs_deserializer_t* restrict des,
                                     char* restrict buffer, size_t buffer_size,
                                     size_t* restrict out_len) {
    if (BCS_UNLIKELY(!des || !out_len))
        return BCS_ERR_NULL_POINTER;

    size_t len;
    bcs_error_t err = bcs_read_bytes_len(des, &len);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;

    /* Need room for null terminator */
    if (BCS_UNLIKELY(len + 1 > buffer_size))
        return BCS_ERR_BUFFER_TOO_SMALL;

    if (BCS_UNLIKELY(des->offset + len > des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    /* Validate UTF-8 */
    if (BCS_UNLIKELY(!bcs_is_valid_utf8(des->data + des->offset, len))) {
        return BCS_ERR_INVALID_UTF8;
    }

    memcpy(buffer, des->data + des->offset, len);
    buffer[len] = '\0';
    des->offset += len;

    *out_len = len;
    return BCS_OK;
}

bcs_error_t bcs_des_enter_struct(bcs_deserializer_t* restrict des) {
    if (BCS_UNLIKELY(!des))
        return BCS_ERR_NULL_POINTER;
    if (BCS_UNLIKELY(des->depth >= BCS_MAX_CONTAINER_DEPTH)) {
        return BCS_ERR_EXCEEDED_CONTAINER_DEPTH;
    }
    des->depth++;
    return BCS_OK;
}

bcs_error_t bcs_des_leave_struct(bcs_deserializer_t* restrict des) {
    if (BCS_UNLIKELY(!des))
        return BCS_ERR_NULL_POINTER;
    if (BCS_LIKELY(des->depth > 0))
        des->depth--;
    return BCS_OK;
}

bcs_error_t bcs_read_variant_index(bcs_deserializer_t* restrict des,
                                   uint32_t* restrict index) {
    if (BCS_UNLIKELY(!des || !index))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->depth >= BCS_MAX_CONTAINER_DEPTH)) {
        return BCS_ERR_EXCEEDED_CONTAINER_DEPTH;
    }
    des->depth++;

    return bcs_read_uleb128(des, index);
}

bcs_error_t bcs_des_leave_enum(bcs_deserializer_t* restrict des) {
    return bcs_des_leave_struct(des);
}

BCS_HOT bcs_error_t bcs_read_option_tag(bcs_deserializer_t* restrict des,
                                         bool* restrict is_some) {
    if (BCS_UNLIKELY(!des || !is_some))
        return BCS_ERR_NULL_POINTER;

    if (BCS_UNLIKELY(des->offset >= des->size))
        return BCS_ERR_UNEXPECTED_EOF;

    uint8_t tag = des->data[des->offset++];
    if (BCS_LIKELY(tag == 0)) {
        *is_some = false;
    } else if (BCS_LIKELY(tag == 1)) {
        *is_some = true;
    } else {
        return BCS_ERR_INVALID_OPTION;
    }
    return BCS_OK;
}

BCS_HOT bcs_error_t bcs_read_vector_len(bcs_deserializer_t* restrict des,
                                         size_t* restrict len) {
    return bcs_read_bytes_len(des, len);
}

BCS_HOT bcs_error_t bcs_read_map_len(bcs_deserializer_t* restrict des,
                                      size_t* restrict len) {
    return bcs_read_vector_len(des, len);
}

size_t bcs_deserializer_offset(const bcs_deserializer_t* des) {
    if (BCS_UNLIKELY(!des))
        return 0;
    return des->offset;
}

const uint8_t* bcs_deserializer_data_at(const bcs_deserializer_t* des, size_t offset) {
    if (BCS_UNLIKELY(!des || offset > des->size))
        return NULL;
    return des->data + offset;
}

int bcs_compare_bytes(const uint8_t* a, size_t a_len, const uint8_t* b, size_t b_len) {
    size_t min_len = (a_len < b_len) ? a_len : b_len;
    for (size_t i = 0; i < min_len; i++) {
        if (a[i] < b[i])
            return -1;
        if (a[i] > b[i])
            return 1;
    }
    if (a_len < b_len)
        return -1;
    if (a_len > b_len)
        return 1;
    return 0;
}

bcs_error_t bcs_read_map_validated(
    bcs_deserializer_t* des,
    bcs_key_deserializer_fn key_deserializer,
    bcs_value_deserializer_fn value_deserializer,
    bcs_map_entry_handler_fn entry_handler,
    void* user_data,
    void* key_scratch,
    void* value_scratch) {

    if (BCS_UNLIKELY(!des || !key_deserializer || !value_deserializer || !entry_handler))
        return BCS_ERR_NULL_POINTER;

    size_t len;
    bcs_error_t err = bcs_read_map_len(des, &len);
    if (BCS_UNLIKELY(err != BCS_OK))
        return err;

    const uint8_t* prev_key_bytes = NULL;
    size_t prev_key_len = 0;

    for (size_t i = 0; i < len; i++) {
        /* Record key start position */
        size_t key_start = des->offset;

        /* Deserialize key */
        err = key_deserializer(des, key_scratch, user_data);
        if (BCS_UNLIKELY(err != BCS_OK))
            return err;

        /* Record key end position */
        size_t key_end = des->offset;
        const uint8_t* key_bytes = des->data + key_start;
        size_t key_len = key_end - key_start;

        /* Validate key ordering */
        if (prev_key_bytes != NULL) {
            int cmp = bcs_compare_bytes(prev_key_bytes, prev_key_len, key_bytes, key_len);
            if (cmp == 0) {
                return BCS_ERR_DUPLICATE_MAP_KEY;
            }
            if (cmp > 0) {
                return BCS_ERR_NON_CANONICAL_MAP;
            }
        }
        prev_key_bytes = key_bytes;
        prev_key_len = key_len;

        /* Deserialize value */
        err = value_deserializer(des, value_scratch, user_data);
        if (BCS_UNLIKELY(err != BCS_OK))
            return err;

        /* Call entry handler */
        err = entry_handler(key_scratch, value_scratch, key_bytes, key_len, user_data);
        if (BCS_UNLIKELY(err != BCS_OK))
            return err;
    }

    return BCS_OK;
}

/* ============================================================================
 * ULEB128 UTILITIES
 * ============================================================================ */

size_t bcs_uleb128_encode(uint32_t value, uint8_t* restrict buffer, size_t buffer_size) {
    if (BCS_UNLIKELY(!buffer || buffer_size == 0))
        return 0;

    size_t i = 0;
    do {
        if (BCS_UNLIKELY(i >= buffer_size))
            return 0;

        uint8_t byte = value & 0x7F;
        value >>= 7;
        if (value != 0) {
            byte |= 0x80;
        }
        buffer[i++] = byte;
    } while (value != 0);

    return i;
}

size_t bcs_uleb128_decode(const uint8_t* restrict data, size_t size,
                          uint32_t* restrict value, bcs_error_t* restrict err) {
    if (BCS_UNLIKELY(!data || !value || !err)) {
        if (err)
            *err = BCS_ERR_NULL_POINTER;
        return 0;
    }

    if (BCS_UNLIKELY(size == 0)) {
        *err = BCS_ERR_UNEXPECTED_EOF;
        return 0;
    }

    /* Fast path for single byte values */
    if (BCS_LIKELY((data[0] & 0x80) == 0)) {
        *value = data[0];
        *err = BCS_OK;
        return 1;
    }

    uint64_t result = 0;
    unsigned shift = 0;
    size_t max_bytes = size < BCS_ULEB128_MAX_BYTES ? size : BCS_ULEB128_MAX_BYTES;

    for (size_t i = 0; i < max_bytes; i++) {
        uint8_t byte = data[i];
        uint8_t digit = byte & 0x7F;

        result |= (uint64_t)digit << shift;

        if ((byte & 0x80) == 0) {
            /* Check for non-canonical encoding */
            if (BCS_UNLIKELY(shift > 0 && digit == 0)) {
                *err = BCS_ERR_NON_CANONICAL_ULEB128;
                return 0;
            }

            /* Check for overflow */
            if (BCS_UNLIKELY(result > 0xFFFFFFFF)) {
                *err = BCS_ERR_ULEB128_OVERFLOW;
                return 0;
            }

            *value = (uint32_t)result;
            *err = BCS_OK;
            return i + 1;
        }

        shift += 7;
    }

    if (max_bytes == BCS_ULEB128_MAX_BYTES) {
        *err = BCS_ERR_ULEB128_OVERFLOW;
    } else {
        *err = BCS_ERR_UNEXPECTED_EOF;
    }
    return 0;
}

BCS_PURE size_t bcs_uleb128_encoded_size(uint32_t value) {
    /* Optimized using bit manipulation - each 7 bits requires one byte */
    if (value < (1U << 7)) return 1;
    if (value < (1U << 14)) return 2;
    if (value < (1U << 21)) return 3;
    if (value < (1U << 28)) return 4;
    return 5;
}

/* ============================================================================
 * UTILITIES
 * ============================================================================ */

BCS_HOT bool bcs_is_valid_utf8(const uint8_t* restrict data, size_t len) {
    if (BCS_UNLIKELY(!data && len > 0))
        return false;

    size_t i = 0;

    /* Fast path: scan for ASCII-only content (very common case)
     * Process 8 bytes at a time when possible */
    while (i + 8 <= len) {
        uint64_t chunk;
        memcpy(&chunk, data + i, 8);
        /* Check if any byte has high bit set */
        if ((chunk & 0x8080808080808080ULL) == 0) {
            i += 8;
            continue;
        }
        break;
    }

    /* Handle remaining bytes (including non-ASCII) */
    while (i < len) {
        uint8_t c = data[i];

        /* ASCII fast path */
        if (BCS_LIKELY((c & 0x80) == 0)) {
            i++;
            continue;
        }

        size_t char_len;
        if ((c & 0xE0) == 0xC0) {
            char_len = 2;
            if (BCS_UNLIKELY(c < 0xC2))
                return false; /* Overlong */
        } else if ((c & 0xF0) == 0xE0) {
            char_len = 3;
        } else if ((c & 0xF8) == 0xF0) {
            char_len = 4;
            if (BCS_UNLIKELY(c > 0xF4))
                return false;
        } else {
            return false;
        }

        if (BCS_UNLIKELY(i + char_len > len))
            return false;

        /* Check continuation bytes */
        for (size_t j = 1; j < char_len; j++) {
            if (BCS_UNLIKELY((data[i + j] & 0xC0) != 0x80))
                return false;
        }

        /* Check overlong encodings and surrogates */
        if (char_len == 3) {
            uint32_t cp =
                ((c & 0x0F) << 12) | ((data[i + 1] & 0x3F) << 6) | (data[i + 2] & 0x3F);
            if (BCS_UNLIKELY(cp < 0x0800))
                return false;
            if (BCS_UNLIKELY(cp >= 0xD800 && cp <= 0xDFFF))
                return false;
        } else if (char_len == 4) {
            uint32_t cp = ((c & 0x07) << 18) | ((data[i + 1] & 0x3F) << 12) |
                          ((data[i + 2] & 0x3F) << 6) | (data[i + 3] & 0x3F);
            if (BCS_UNLIKELY(cp < 0x10000 || cp > 0x10FFFF))
                return false;
        }

        i += char_len;
    }

    return true;
}

/* Lookup table for hex digit values (-1 for invalid) */
static const int8_t hex_values[256] = {
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
     0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,  /* 0-9 */
    -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,  /* A-F */
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,  /* a-f */
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
};

size_t bcs_bytes_to_hex(const uint8_t* restrict bytes, size_t len,
                        char* restrict hex_buffer, size_t buffer_size) {
    if (BCS_UNLIKELY(!hex_buffer || buffer_size == 0))
        return 0;
    if (BCS_UNLIKELY(len > 0 && !bytes))
        return 0;

    static const char hex_chars[] = "0123456789abcdef";
    size_t max_bytes = (buffer_size - 1) / 2;
    size_t to_write = len < max_bytes ? len : max_bytes;

    for (size_t i = 0; i < to_write; i++) {
        hex_buffer[i * 2] = hex_chars[(bytes[i] >> 4) & 0x0F];
        hex_buffer[i * 2 + 1] = hex_chars[bytes[i] & 0x0F];
    }
    hex_buffer[to_write * 2] = '\0';

    return to_write * 2;
}

size_t bcs_hex_to_bytes(const char* restrict hex, uint8_t* restrict buffer,
                        size_t buffer_size) {
    if (BCS_UNLIKELY(!hex || !buffer))
        return 0;

    size_t hex_len = strlen(hex);
    if (BCS_UNLIKELY(hex_len % 2 != 0))
        return 0;

    size_t byte_len = hex_len / 2;
    if (BCS_UNLIKELY(byte_len > buffer_size))
        return 0;

    for (size_t i = 0; i < byte_len; i++) {
        int8_t high = hex_values[(unsigned char)hex[i * 2]];
        int8_t low = hex_values[(unsigned char)hex[i * 2 + 1]];
        if (BCS_UNLIKELY(high < 0 || low < 0))
            return 0;
        buffer[i] = (uint8_t)((high << 4) | low);
    }

    return byte_len;
}
