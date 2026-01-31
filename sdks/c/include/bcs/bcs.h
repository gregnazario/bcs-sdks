/**
 * @file bcs.h
 * @brief Binary Canonical Serialization (BCS) for C
 *
 * A C99 implementation of the BCS serialization format.
 */

#ifndef BCS_H
#define BCS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * CONSTANTS
 * ============================================================================ */

/** Maximum length for variable-length sequences (2^31 - 1) */
#define BCS_MAX_SEQUENCE_LENGTH 0x7FFFFFFF

/** Maximum container depth for nested structures */
#define BCS_MAX_CONTAINER_DEPTH 500

/** Maximum bytes in ULEB128 encoding for u32 */
#define BCS_ULEB128_MAX_BYTES 5

/* ============================================================================
 * ERROR CODES
 * ============================================================================ */

/** BCS error codes */
typedef enum {
    BCS_OK = 0,
    BCS_ERR_UNEXPECTED_EOF,
    BCS_ERR_INVALID_BOOLEAN,
    BCS_ERR_NON_CANONICAL_ULEB128,
    BCS_ERR_ULEB128_OVERFLOW,
    BCS_ERR_EXCEEDED_MAX_LENGTH,
    BCS_ERR_EXCEEDED_CONTAINER_DEPTH,
    BCS_ERR_INVALID_UTF8,
    BCS_ERR_NON_CANONICAL_MAP,
    BCS_ERR_DUPLICATE_MAP_KEY,
    BCS_ERR_INTEGER_OUT_OF_RANGE,
    BCS_ERR_REMAINING_INPUT,
    BCS_ERR_INVALID_OPTION,
    BCS_ERR_BUFFER_TOO_SMALL,
    BCS_ERR_NULL_POINTER,
    BCS_ERR_ALLOCATION_FAILED
} bcs_error_t;

/** Get error message for error code */
const char* bcs_error_message(bcs_error_t err);

/* ============================================================================
 * SERIALIZER
 * ============================================================================ */

/** Serializer state */
typedef struct {
    uint8_t* buffer;  /**< Output buffer */
    size_t capacity;  /**< Buffer capacity */
    size_t size;      /**< Current size (bytes written) */
    int depth;        /**< Current container depth */
    bool owns_buffer; /**< Whether we own the buffer (for cleanup) */
} bcs_serializer_t;

/** Initialize serializer with external buffer */
bcs_error_t bcs_serializer_init(bcs_serializer_t* ser, uint8_t* buffer,
                                size_t capacity);

/** Initialize serializer with dynamically allocated buffer */
bcs_error_t bcs_serializer_init_dynamic(bcs_serializer_t* ser, size_t initial_capacity);

/** Free serializer resources */
void bcs_serializer_free(bcs_serializer_t* ser);

/** Reset serializer for reuse */
void bcs_serializer_reset(bcs_serializer_t* ser);

/** Get serialized bytes and size */
const uint8_t* bcs_serializer_bytes(const bcs_serializer_t* ser);
size_t bcs_serializer_size(const bcs_serializer_t* ser);

/* Boolean */
bcs_error_t bcs_write_bool(bcs_serializer_t* ser, bool value);

/* Unsigned integers */
bcs_error_t bcs_write_u8(bcs_serializer_t* ser, uint8_t value);
bcs_error_t bcs_write_u16(bcs_serializer_t* ser, uint16_t value);
bcs_error_t bcs_write_u32(bcs_serializer_t* ser, uint32_t value);
bcs_error_t bcs_write_u64(bcs_serializer_t* ser, uint64_t value);
bcs_error_t bcs_write_u128(bcs_serializer_t* ser, const uint8_t value[16]);
bcs_error_t bcs_write_u256(bcs_serializer_t* ser, const uint8_t value[32]);

/* Signed integers */
bcs_error_t bcs_write_i8(bcs_serializer_t* ser, int8_t value);
bcs_error_t bcs_write_i16(bcs_serializer_t* ser, int16_t value);
bcs_error_t bcs_write_i32(bcs_serializer_t* ser, int32_t value);
bcs_error_t bcs_write_i64(bcs_serializer_t* ser, int64_t value);
bcs_error_t bcs_write_i128(bcs_serializer_t* ser, const uint8_t value[16]);
bcs_error_t bcs_write_i256(bcs_serializer_t* ser, const uint8_t value[32]);

/* ULEB128 */
bcs_error_t bcs_write_uleb128(bcs_serializer_t* ser, uint32_t value);

/* Bytes and strings */
bcs_error_t bcs_write_fixed_bytes(bcs_serializer_t* ser, const uint8_t* data,
                                  size_t len);
bcs_error_t bcs_write_bytes(bcs_serializer_t* ser, const uint8_t* data, size_t len);
bcs_error_t bcs_write_string(bcs_serializer_t* ser, const char* str);
bcs_error_t bcs_write_string_n(bcs_serializer_t* ser, const char* str, size_t len);

/* Container depth tracking */
bcs_error_t bcs_enter_struct(bcs_serializer_t* ser);
bcs_error_t bcs_leave_struct(bcs_serializer_t* ser);
bcs_error_t bcs_write_variant_index(bcs_serializer_t* ser, uint32_t index);
bcs_error_t bcs_leave_enum(bcs_serializer_t* ser);

/* Options */
bcs_error_t bcs_write_option_none(bcs_serializer_t* ser);
bcs_error_t bcs_write_option_some(bcs_serializer_t* ser);

/* Vectors - write length, then caller writes elements */
bcs_error_t bcs_write_vector_len(bcs_serializer_t* ser, size_t len);

/* Maps - write length, then caller writes sorted key/value pairs */
bcs_error_t bcs_write_map_len(bcs_serializer_t* ser, size_t len);

/* ============================================================================
 * DESERIALIZER
 * ============================================================================ */

/** Deserializer state */
typedef struct {
    const uint8_t* data; /**< Input data */
    size_t size;         /**< Total size */
    size_t offset;       /**< Current read position */
    int depth;           /**< Current container depth */
} bcs_deserializer_t;

/** Initialize deserializer */
bcs_error_t bcs_deserializer_init(bcs_deserializer_t* des, const uint8_t* data,
                                  size_t size);

/** Check that all input has been consumed */
bcs_error_t bcs_check_end(const bcs_deserializer_t* des);

/** Get remaining bytes count */
size_t bcs_remaining(const bcs_deserializer_t* des);

/* Boolean */
bcs_error_t bcs_read_bool(bcs_deserializer_t* des, bool* value);

/* Unsigned integers */
bcs_error_t bcs_read_u8(bcs_deserializer_t* des, uint8_t* value);
bcs_error_t bcs_read_u16(bcs_deserializer_t* des, uint16_t* value);
bcs_error_t bcs_read_u32(bcs_deserializer_t* des, uint32_t* value);
bcs_error_t bcs_read_u64(bcs_deserializer_t* des, uint64_t* value);
bcs_error_t bcs_read_u128(bcs_deserializer_t* des, uint8_t value[16]);
bcs_error_t bcs_read_u256(bcs_deserializer_t* des, uint8_t value[32]);

/* Signed integers */
bcs_error_t bcs_read_i8(bcs_deserializer_t* des, int8_t* value);
bcs_error_t bcs_read_i16(bcs_deserializer_t* des, int16_t* value);
bcs_error_t bcs_read_i32(bcs_deserializer_t* des, int32_t* value);
bcs_error_t bcs_read_i64(bcs_deserializer_t* des, int64_t* value);
bcs_error_t bcs_read_i128(bcs_deserializer_t* des, uint8_t value[16]);
bcs_error_t bcs_read_i256(bcs_deserializer_t* des, uint8_t value[32]);

/* ULEB128 */
bcs_error_t bcs_read_uleb128(bcs_deserializer_t* des, uint32_t* value);

/* Bytes and strings */
bcs_error_t bcs_read_fixed_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t len);
bcs_error_t bcs_read_bytes_len(bcs_deserializer_t* des, size_t* len);
bcs_error_t bcs_read_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t buffer_size,
                           size_t* out_len);
bcs_error_t bcs_read_string(bcs_deserializer_t* des, char* buffer, size_t buffer_size,
                            size_t* out_len);

/* Container depth tracking */
bcs_error_t bcs_des_enter_struct(bcs_deserializer_t* des);
bcs_error_t bcs_des_leave_struct(bcs_deserializer_t* des);
bcs_error_t bcs_read_variant_index(bcs_deserializer_t* des, uint32_t* index);
bcs_error_t bcs_des_leave_enum(bcs_deserializer_t* des);

/* Options */
bcs_error_t bcs_read_option_tag(bcs_deserializer_t* des, bool* is_some);

/* Vectors */
bcs_error_t bcs_read_vector_len(bcs_deserializer_t* des, size_t* len);

/* Maps */
bcs_error_t bcs_read_map_len(bcs_deserializer_t* des, size_t* len);

/** Get current deserializer offset (for tracking key positions) */
size_t bcs_deserializer_offset(const bcs_deserializer_t* des);

/** Get pointer to data at offset (for key comparison) */
const uint8_t* bcs_deserializer_data_at(const bcs_deserializer_t* des, size_t offset);

/** Compare two byte sequences lexicographically.
 *  Returns: < 0 if a < b, 0 if a == b, > 0 if a > b
 */
int bcs_compare_bytes(const uint8_t* a, size_t a_len, const uint8_t* b, size_t b_len);

/**
 * Callback function type for deserializing map keys.
 * Should return BCS_OK on success, error code on failure.
 * The key_start and key_end offsets can be used for key comparison.
 */
typedef bcs_error_t (*bcs_key_deserializer_fn)(bcs_deserializer_t* des, void* key_out,
                                               void* user_data);

/**
 * Callback function type for deserializing map values.
 */
typedef bcs_error_t (*bcs_value_deserializer_fn)(bcs_deserializer_t* des,
                                                 void* value_out, void* user_data);

/**
 * Callback function type for handling a deserialized key-value pair.
 * Called with the key, value, and their serialized byte positions.
 */
typedef bcs_error_t (*bcs_map_entry_handler_fn)(void* key, void* value,
                                                const uint8_t* key_bytes,
                                                size_t key_len, void* user_data);

/**
 * Read and validate a map with callbacks.
 * Validates that keys are sorted and rejects duplicates.
 *
 * @param des The deserializer
 * @param key_deserializer Callback to deserialize each key
 * @param value_deserializer Callback to deserialize each value
 * @param entry_handler Callback to handle each key-value pair
 * @param user_data User data passed to callbacks
 * @param key_scratch Scratch buffer for storing temporary key (can be NULL if
 * entry_handler stores keys)
 * @param value_scratch Scratch buffer for storing temporary value
 * @return BCS_OK on success, error code on failure
 */
bcs_error_t bcs_read_map_validated(bcs_deserializer_t* des,
                                   bcs_key_deserializer_fn key_deserializer,
                                   bcs_value_deserializer_fn value_deserializer,
                                   bcs_map_entry_handler_fn entry_handler,
                                   void* user_data, void* key_scratch,
                                   void* value_scratch);

/* ============================================================================
 * ULEB128 UTILITIES
 * ============================================================================ */

/** Encode a u32 as ULEB128. Returns bytes written or 0 on error. */
size_t bcs_uleb128_encode(uint32_t value, uint8_t* buffer, size_t buffer_size);

/** Decode ULEB128. Returns bytes read or 0 on error. Sets error code. */
size_t bcs_uleb128_decode(const uint8_t* data, size_t size, uint32_t* value,
                          bcs_error_t* err);

/** Get encoded size for a value */
size_t bcs_uleb128_encoded_size(uint32_t value);

/* ============================================================================
 * UTILITIES
 * ============================================================================ */

/** Validate UTF-8 encoding */
bool bcs_is_valid_utf8(const uint8_t* data, size_t len);

/** Convert bytes to hex string. Returns chars written (excluding null). */
size_t bcs_bytes_to_hex(const uint8_t* bytes, size_t len, char* hex_buffer,
                        size_t buffer_size);

/** Convert hex string to bytes. Returns bytes written or 0 on error. */
size_t bcs_hex_to_bytes(const char* hex, uint8_t* buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif

#endif /* BCS_H */
