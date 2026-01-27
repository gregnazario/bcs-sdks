/**
 * @file bcs.c
 * @brief BCS implementation
 */

#include "bcs/bcs.h"

#include <stdlib.h>
#include <string.h>

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

static bcs_error_t ensure_capacity(bcs_serializer_t* ser, size_t needed) {
    size_t required = ser->size + needed;
    if (required <= ser->capacity) {
        return BCS_OK;
    }

    if (!ser->owns_buffer) {
        return BCS_ERR_BUFFER_TOO_SMALL;
    }

    /* Grow buffer (double or required, whichever is larger) */
    size_t new_capacity = ser->capacity * 2;
    if (new_capacity < required) {
        new_capacity = required;
    }

    uint8_t* new_buffer = (uint8_t*)realloc(ser->buffer, new_capacity);
    if (!new_buffer) {
        return BCS_ERR_ALLOCATION_FAILED;
    }

    ser->buffer = new_buffer;
    ser->capacity = new_capacity;
    return BCS_OK;
}

static bcs_error_t write_byte(bcs_serializer_t* ser, uint8_t byte) {
    bcs_error_t err = ensure_capacity(ser, 1);
    if (err != BCS_OK)
        return err;
    ser->buffer[ser->size++] = byte;
    return BCS_OK;
}

static bcs_error_t write_bytes_raw(bcs_serializer_t* ser, const uint8_t* data,
                                   size_t len) {
    bcs_error_t err = ensure_capacity(ser, len);
    if (err != BCS_OK)
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

bcs_error_t bcs_write_bool(bcs_serializer_t* ser, bool value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, value ? 1 : 0);
}

bcs_error_t bcs_write_u8(bcs_serializer_t* ser, uint8_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, value);
}

bcs_error_t bcs_write_u16(bcs_serializer_t* ser, uint16_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    uint8_t bytes[2] = {(uint8_t)(value & 0xFF), (uint8_t)((value >> 8) & 0xFF)};
    return write_bytes_raw(ser, bytes, 2);
}

bcs_error_t bcs_write_u32(bcs_serializer_t* ser, uint32_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    uint8_t bytes[4];
    for (int i = 0; i < 4; i++) {
        bytes[i] = (uint8_t)((value >> (i * 8)) & 0xFF);
    }
    return write_bytes_raw(ser, bytes, 4);
}

bcs_error_t bcs_write_u64(bcs_serializer_t* ser, uint64_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    uint8_t bytes[8];
    for (int i = 0; i < 8; i++) {
        bytes[i] = (uint8_t)((value >> (i * 8)) & 0xFF);
    }
    return write_bytes_raw(ser, bytes, 8);
}

bcs_error_t bcs_write_u128(bcs_serializer_t* ser, const uint8_t value[16]) {
    if (!ser || !value)
        return BCS_ERR_NULL_POINTER;
    return write_bytes_raw(ser, value, 16);
}

bcs_error_t bcs_write_u256(bcs_serializer_t* ser, const uint8_t value[32]) {
    if (!ser || !value)
        return BCS_ERR_NULL_POINTER;
    return write_bytes_raw(ser, value, 32);
}

bcs_error_t bcs_write_i8(bcs_serializer_t* ser, int8_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, (uint8_t)value);
}

bcs_error_t bcs_write_i16(bcs_serializer_t* ser, int16_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return bcs_write_u16(ser, (uint16_t)value);
}

bcs_error_t bcs_write_i32(bcs_serializer_t* ser, int32_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return bcs_write_u32(ser, (uint32_t)value);
}

bcs_error_t bcs_write_i64(bcs_serializer_t* ser, int64_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return bcs_write_u64(ser, (uint64_t)value);
}

bcs_error_t bcs_write_i128(bcs_serializer_t* ser, const uint8_t value[16]) {
    return bcs_write_u128(ser, value);
}

bcs_error_t bcs_write_i256(bcs_serializer_t* ser, const uint8_t value[32]) {
    return bcs_write_u256(ser, value);
}

bcs_error_t bcs_write_uleb128(bcs_serializer_t* ser, uint32_t value) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;

    uint8_t bytes[BCS_ULEB128_MAX_BYTES];
    size_t len = bcs_uleb128_encode(value, bytes, sizeof(bytes));
    if (len == 0)
        return BCS_ERR_BUFFER_TOO_SMALL;

    return write_bytes_raw(ser, bytes, len);
}

bcs_error_t bcs_write_fixed_bytes(bcs_serializer_t* ser, const uint8_t* data,
                                  size_t len) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    if (len > 0 && !data)
        return BCS_ERR_NULL_POINTER;
    return write_bytes_raw(ser, data, len);
}

bcs_error_t bcs_write_bytes(bcs_serializer_t* ser, const uint8_t* data, size_t len) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    if (len > BCS_MAX_SEQUENCE_LENGTH)
        return BCS_ERR_EXCEEDED_MAX_LENGTH;

    bcs_error_t err = bcs_write_uleb128(ser, (uint32_t)len);
    if (err != BCS_OK)
        return err;

    return bcs_write_fixed_bytes(ser, data, len);
}

bcs_error_t bcs_write_string(bcs_serializer_t* ser, const char* str) {
    if (!ser || !str)
        return BCS_ERR_NULL_POINTER;
    return bcs_write_bytes(ser, (const uint8_t*)str, strlen(str));
}

bcs_error_t bcs_write_string_n(bcs_serializer_t* ser, const char* str, size_t len) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    if (len > 0 && !str)
        return BCS_ERR_NULL_POINTER;
    return bcs_write_bytes(ser, (const uint8_t*)str, len);
}

bcs_error_t bcs_enter_struct(bcs_serializer_t* ser) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    if (ser->depth >= BCS_MAX_CONTAINER_DEPTH) {
        return BCS_ERR_EXCEEDED_CONTAINER_DEPTH;
    }
    ser->depth++;
    return BCS_OK;
}

bcs_error_t bcs_leave_struct(bcs_serializer_t* ser) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    if (ser->depth > 0)
        ser->depth--;
    return BCS_OK;
}

bcs_error_t bcs_write_variant_index(bcs_serializer_t* ser, uint32_t index) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    bcs_error_t err = bcs_enter_struct(ser);
    if (err != BCS_OK)
        return err;
    return bcs_write_uleb128(ser, index);
}

bcs_error_t bcs_leave_enum(bcs_serializer_t* ser) {
    return bcs_leave_struct(ser);
}

bcs_error_t bcs_write_option_none(bcs_serializer_t* ser) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, 0);
}

bcs_error_t bcs_write_option_some(bcs_serializer_t* ser) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    return write_byte(ser, 1);
}

bcs_error_t bcs_write_vector_len(bcs_serializer_t* ser, size_t len) {
    if (!ser)
        return BCS_ERR_NULL_POINTER;
    if (len > BCS_MAX_SEQUENCE_LENGTH)
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    return bcs_write_uleb128(ser, (uint32_t)len);
}

/* ============================================================================
 * DESERIALIZER
 * ============================================================================ */

bcs_error_t bcs_deserializer_init(bcs_deserializer_t* des, const uint8_t* data,
                                  size_t size) {
    if (!des)
        return BCS_ERR_NULL_POINTER;
    if (size > 0 && !data)
        return BCS_ERR_NULL_POINTER;

    des->data = data;
    des->size = size;
    des->offset = 0;
    des->depth = 0;
    return BCS_OK;
}

bcs_error_t bcs_check_end(const bcs_deserializer_t* des) {
    if (!des)
        return BCS_ERR_NULL_POINTER;
    if (des->offset < des->size)
        return BCS_ERR_REMAINING_INPUT;
    return BCS_OK;
}

size_t bcs_remaining(const bcs_deserializer_t* des) {
    if (!des)
        return 0;
    return des->size - des->offset;
}

static bcs_error_t check_remaining(const bcs_deserializer_t* des, size_t needed) {
    if (des->offset + needed > des->size) {
        return BCS_ERR_UNEXPECTED_EOF;
    }
    return BCS_OK;
}

bcs_error_t bcs_read_bool(bcs_deserializer_t* des, bool* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;

    uint8_t byte;
    bcs_error_t err = bcs_read_u8(des, &byte);
    if (err != BCS_OK)
        return err;

    if (byte == 0) {
        *value = false;
    } else if (byte == 1) {
        *value = true;
    } else {
        return BCS_ERR_INVALID_BOOLEAN;
    }
    return BCS_OK;
}

bcs_error_t bcs_read_u8(bcs_deserializer_t* des, uint8_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;

    bcs_error_t err = check_remaining(des, 1);
    if (err != BCS_OK)
        return err;

    *value = des->data[des->offset++];
    return BCS_OK;
}

bcs_error_t bcs_read_u16(bcs_deserializer_t* des, uint16_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;

    bcs_error_t err = check_remaining(des, 2);
    if (err != BCS_OK)
        return err;

    *value =
        (uint16_t)des->data[des->offset] | ((uint16_t)des->data[des->offset + 1] << 8);
    des->offset += 2;
    return BCS_OK;
}

bcs_error_t bcs_read_u32(bcs_deserializer_t* des, uint32_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;

    bcs_error_t err = check_remaining(des, 4);
    if (err != BCS_OK)
        return err;

    *value = 0;
    for (int i = 0; i < 4; i++) {
        *value |= (uint32_t)des->data[des->offset + i] << (i * 8);
    }
    des->offset += 4;
    return BCS_OK;
}

bcs_error_t bcs_read_u64(bcs_deserializer_t* des, uint64_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;

    bcs_error_t err = check_remaining(des, 8);
    if (err != BCS_OK)
        return err;

    *value = 0;
    for (int i = 0; i < 8; i++) {
        *value |= (uint64_t)des->data[des->offset + i] << (i * 8);
    }
    des->offset += 8;
    return BCS_OK;
}

bcs_error_t bcs_read_u128(bcs_deserializer_t* des, uint8_t value[16]) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;
    return bcs_read_fixed_bytes(des, value, 16);
}

bcs_error_t bcs_read_u256(bcs_deserializer_t* des, uint8_t value[32]) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;
    return bcs_read_fixed_bytes(des, value, 32);
}

bcs_error_t bcs_read_i8(bcs_deserializer_t* des, int8_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;
    uint8_t u;
    bcs_error_t err = bcs_read_u8(des, &u);
    if (err != BCS_OK)
        return err;
    *value = (int8_t)u;
    return BCS_OK;
}

bcs_error_t bcs_read_i16(bcs_deserializer_t* des, int16_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;
    uint16_t u;
    bcs_error_t err = bcs_read_u16(des, &u);
    if (err != BCS_OK)
        return err;
    *value = (int16_t)u;
    return BCS_OK;
}

bcs_error_t bcs_read_i32(bcs_deserializer_t* des, int32_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;
    uint32_t u;
    bcs_error_t err = bcs_read_u32(des, &u);
    if (err != BCS_OK)
        return err;
    *value = (int32_t)u;
    return BCS_OK;
}

bcs_error_t bcs_read_i64(bcs_deserializer_t* des, int64_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;
    uint64_t u;
    bcs_error_t err = bcs_read_u64(des, &u);
    if (err != BCS_OK)
        return err;
    *value = (int64_t)u;
    return BCS_OK;
}

bcs_error_t bcs_read_i128(bcs_deserializer_t* des, uint8_t value[16]) {
    return bcs_read_u128(des, value);
}

bcs_error_t bcs_read_i256(bcs_deserializer_t* des, uint8_t value[32]) {
    return bcs_read_u256(des, value);
}

bcs_error_t bcs_read_uleb128(bcs_deserializer_t* des, uint32_t* value) {
    if (!des || !value)
        return BCS_ERR_NULL_POINTER;

    bcs_error_t err;
    size_t bytes_read = bcs_uleb128_decode(des->data + des->offset,
                                           des->size - des->offset, value, &err);
    if (bytes_read == 0)
        return err;

    des->offset += bytes_read;
    return BCS_OK;
}

bcs_error_t bcs_read_fixed_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t len) {
    if (!des)
        return BCS_ERR_NULL_POINTER;
    if (len > 0 && !buffer)
        return BCS_ERR_NULL_POINTER;

    bcs_error_t err = check_remaining(des, len);
    if (err != BCS_OK)
        return err;

    memcpy(buffer, des->data + des->offset, len);
    des->offset += len;
    return BCS_OK;
}

bcs_error_t bcs_read_bytes_len(bcs_deserializer_t* des, size_t* len) {
    if (!des || !len)
        return BCS_ERR_NULL_POINTER;

    uint32_t uleb_len;
    bcs_error_t err = bcs_read_uleb128(des, &uleb_len);
    if (err != BCS_OK)
        return err;

    if (uleb_len > BCS_MAX_SEQUENCE_LENGTH) {
        return BCS_ERR_EXCEEDED_MAX_LENGTH;
    }

    *len = uleb_len;
    return BCS_OK;
}

bcs_error_t bcs_read_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t buffer_size,
                           size_t* out_len) {
    if (!des || !out_len)
        return BCS_ERR_NULL_POINTER;

    size_t len;
    bcs_error_t err = bcs_read_bytes_len(des, &len);
    if (err != BCS_OK)
        return err;

    if (len > buffer_size)
        return BCS_ERR_BUFFER_TOO_SMALL;

    err = bcs_read_fixed_bytes(des, buffer, len);
    if (err != BCS_OK)
        return err;

    *out_len = len;
    return BCS_OK;
}

bcs_error_t bcs_read_string(bcs_deserializer_t* des, char* buffer, size_t buffer_size,
                            size_t* out_len) {
    if (!des || !out_len)
        return BCS_ERR_NULL_POINTER;

    size_t len;
    bcs_error_t err = bcs_read_bytes_len(des, &len);
    if (err != BCS_OK)
        return err;

    /* Need room for null terminator */
    if (len + 1 > buffer_size)
        return BCS_ERR_BUFFER_TOO_SMALL;

    err = check_remaining(des, len);
    if (err != BCS_OK)
        return err;

    /* Validate UTF-8 */
    if (!bcs_is_valid_utf8(des->data + des->offset, len)) {
        return BCS_ERR_INVALID_UTF8;
    }

    memcpy(buffer, des->data + des->offset, len);
    buffer[len] = '\0';
    des->offset += len;

    *out_len = len;
    return BCS_OK;
}

bcs_error_t bcs_des_enter_struct(bcs_deserializer_t* des) {
    if (!des)
        return BCS_ERR_NULL_POINTER;
    if (des->depth >= BCS_MAX_CONTAINER_DEPTH) {
        return BCS_ERR_EXCEEDED_CONTAINER_DEPTH;
    }
    des->depth++;
    return BCS_OK;
}

bcs_error_t bcs_des_leave_struct(bcs_deserializer_t* des) {
    if (!des)
        return BCS_ERR_NULL_POINTER;
    if (des->depth > 0)
        des->depth--;
    return BCS_OK;
}

bcs_error_t bcs_read_variant_index(bcs_deserializer_t* des, uint32_t* index) {
    if (!des || !index)
        return BCS_ERR_NULL_POINTER;

    bcs_error_t err = bcs_des_enter_struct(des);
    if (err != BCS_OK)
        return err;

    return bcs_read_uleb128(des, index);
}

bcs_error_t bcs_des_leave_enum(bcs_deserializer_t* des) {
    return bcs_des_leave_struct(des);
}

bcs_error_t bcs_read_option_tag(bcs_deserializer_t* des, bool* is_some) {
    if (!des || !is_some)
        return BCS_ERR_NULL_POINTER;

    uint8_t tag;
    bcs_error_t err = bcs_read_u8(des, &tag);
    if (err != BCS_OK)
        return err;

    if (tag == 0) {
        *is_some = false;
    } else if (tag == 1) {
        *is_some = true;
    } else {
        return BCS_ERR_INVALID_OPTION;
    }
    return BCS_OK;
}

bcs_error_t bcs_read_vector_len(bcs_deserializer_t* des, size_t* len) {
    return bcs_read_bytes_len(des, len);
}

/* ============================================================================
 * ULEB128 UTILITIES
 * ============================================================================ */

size_t bcs_uleb128_encode(uint32_t value, uint8_t* buffer, size_t buffer_size) {
    if (!buffer || buffer_size == 0)
        return 0;

    size_t i = 0;
    do {
        if (i >= buffer_size)
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

size_t bcs_uleb128_decode(const uint8_t* data, size_t size, uint32_t* value,
                          bcs_error_t* err) {
    if (!data || !value || !err) {
        if (err)
            *err = BCS_ERR_NULL_POINTER;
        return 0;
    }

    uint64_t result = 0;
    unsigned shift = 0;
    size_t bytes_read = 0;

    for (size_t i = 0; i < BCS_ULEB128_MAX_BYTES && i < size; i++) {
        uint8_t byte = data[i];
        uint8_t digit = byte & 0x7F;

        result |= (uint64_t)digit << shift;
        bytes_read = i + 1;

        if ((byte & 0x80) == 0) {
            /* Check for non-canonical encoding */
            if (shift > 0 && digit == 0) {
                *err = BCS_ERR_NON_CANONICAL_ULEB128;
                return 0;
            }

            /* Check for overflow */
            if (result > 0xFFFFFFFF) {
                *err = BCS_ERR_ULEB128_OVERFLOW;
                return 0;
            }

            *value = (uint32_t)result;
            *err = BCS_OK;
            return bytes_read;
        }

        shift += 7;
    }

    if (bytes_read == BCS_ULEB128_MAX_BYTES) {
        *err = BCS_ERR_ULEB128_OVERFLOW;
    } else {
        *err = BCS_ERR_UNEXPECTED_EOF;
    }
    return 0;
}

size_t bcs_uleb128_encoded_size(uint32_t value) {
    size_t size = 1;
    while (value >= 0x80) {
        value >>= 7;
        size++;
    }
    return size;
}

/* ============================================================================
 * UTILITIES
 * ============================================================================ */

bool bcs_is_valid_utf8(const uint8_t* data, size_t len) {
    if (!data && len > 0)
        return false;

    size_t i = 0;
    while (i < len) {
        uint8_t c = data[i];
        size_t char_len;

        if ((c & 0x80) == 0) {
            char_len = 1;
        } else if ((c & 0xE0) == 0xC0) {
            char_len = 2;
            if (c < 0xC2)
                return false; /* Overlong */
        } else if ((c & 0xF0) == 0xE0) {
            char_len = 3;
        } else if ((c & 0xF8) == 0xF0) {
            char_len = 4;
            if (c > 0xF4)
                return false;
        } else {
            return false;
        }

        if (i + char_len > len)
            return false;

        /* Check continuation bytes */
        for (size_t j = 1; j < char_len; j++) {
            if ((data[i + j] & 0xC0) != 0x80)
                return false;
        }

        /* Check overlong encodings and surrogates */
        if (char_len == 3) {
            uint32_t cp =
                ((c & 0x0F) << 12) | ((data[i + 1] & 0x3F) << 6) | (data[i + 2] & 0x3F);
            if (cp < 0x0800)
                return false;
            if (cp >= 0xD800 && cp <= 0xDFFF)
                return false;
        } else if (char_len == 4) {
            uint32_t cp = ((c & 0x07) << 18) | ((data[i + 1] & 0x3F) << 12) |
                          ((data[i + 2] & 0x3F) << 6) | (data[i + 3] & 0x3F);
            if (cp < 0x10000 || cp > 0x10FFFF)
                return false;
        }

        i += char_len;
    }

    return true;
}

static int hex_digit_value(char c) {
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

size_t bcs_bytes_to_hex(const uint8_t* bytes, size_t len, char* hex_buffer,
                        size_t buffer_size) {
    if (!hex_buffer || buffer_size == 0)
        return 0;
    if (len > 0 && !bytes)
        return 0;

    static const char hex_chars[] = "0123456789abcdef";
    size_t written = 0;

    for (size_t i = 0; i < len && written + 2 < buffer_size; i++) {
        hex_buffer[written++] = hex_chars[(bytes[i] >> 4) & 0x0F];
        hex_buffer[written++] = hex_chars[bytes[i] & 0x0F];
    }

    if (written < buffer_size) {
        hex_buffer[written] = '\0';
    }

    return written;
}

size_t bcs_hex_to_bytes(const char* hex, uint8_t* buffer, size_t buffer_size) {
    if (!hex || !buffer)
        return 0;

    size_t hex_len = strlen(hex);
    if (hex_len % 2 != 0)
        return 0;

    size_t byte_len = hex_len / 2;
    if (byte_len > buffer_size)
        return 0;

    for (size_t i = 0; i < byte_len; i++) {
        int high = hex_digit_value(hex[i * 2]);
        int low = hex_digit_value(hex[i * 2 + 1]);
        if (high < 0 || low < 0)
            return 0;
        buffer[i] = (uint8_t)((high << 4) | low);
    }

    return byte_len;
}
