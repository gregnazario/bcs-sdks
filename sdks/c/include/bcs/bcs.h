/**
 * @file bcs.h
 * @brief Binary Canonical Serialization (BCS) for C
 *
 * A C99 implementation of the BCS serialization format. BCS is a deterministic
 * binary serialization format that guarantees canonical representation -- every
 * value has exactly one valid serialized form.
 *
 * @par Quick Start
 * @code
 * uint8_t buffer[256];
 * bcs_serializer_t ser;
 * bcs_serializer_init(&ser, buffer, sizeof(buffer));
 * bcs_write_u64(&ser, 12345);
 * bcs_write_string(&ser, "hello");
 *
 * bcs_deserializer_t des;
 * bcs_deserializer_init(&des, buffer, bcs_serializer_size(&ser));
 * uint64_t num;
 * bcs_read_u64(&des, &num);
 * @endcode
 *
 * @par Error Handling
 * All serialization/deserialization functions return @c bcs_error_t.
 * Check for @c BCS_OK on success. Use bcs_error_message() for descriptive
 * error strings.
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

/**
 * Get a human-readable error message for an error code.
 *
 * @param err The error code to describe.
 * @return A static string describing the error. Never returns NULL.
 */
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

/**
 * Initialize a serializer with a caller-provided buffer.
 *
 * @param[out] ser  Serializer to initialize.
 * @param[in]  buffer  Caller-owned buffer for output.
 * @param[in]  capacity  Size of @p buffer in bytes.
 * @return BCS_OK on success, BCS_ERR_NULL_POINTER if @p ser or @p buffer is NULL.
 */
bcs_error_t bcs_serializer_init(bcs_serializer_t* ser, uint8_t* buffer,
                                size_t capacity);

/**
 * Initialize a serializer with a dynamically allocated buffer that auto-grows.
 *
 * The buffer is owned by the serializer and must be freed with bcs_serializer_free().
 *
 * @param[out] ser  Serializer to initialize.
 * @param[in]  initial_capacity  Initial buffer capacity in bytes.
 * @return BCS_OK on success, BCS_ERR_ALLOCATION_FAILED on allocation failure.
 */
bcs_error_t bcs_serializer_init_dynamic(bcs_serializer_t* ser, size_t initial_capacity);

/**
 * Free resources held by the serializer.
 *
 * Only needed when the serializer was initialized with bcs_serializer_init_dynamic().
 *
 * @param[in,out] ser  Serializer to free. Safe to call on a NULL pointer.
 */
void bcs_serializer_free(bcs_serializer_t* ser);

/**
 * Reset the serializer for reuse without reallocating its buffer.
 *
 * @param[in,out] ser  Serializer to reset.
 */
void bcs_serializer_reset(bcs_serializer_t* ser);

/**
 * Get a pointer to the serialized bytes.
 *
 * @param[in] ser  The serializer.
 * @return Pointer to the serialized output buffer.
 */
const uint8_t* bcs_serializer_bytes(const bcs_serializer_t* ser);

/**
 * Get the number of bytes written to the serializer.
 *
 * @param[in] ser  The serializer.
 * @return Number of serialized bytes.
 */
size_t bcs_serializer_size(const bcs_serializer_t* ser);

/* Boolean */

/** @brief Serialize a boolean value (0x00 = false, 0x01 = true).
 *  @param[in,out] ser  The serializer.
 *  @param[in]     value  Boolean value to serialize.
 *  @return BCS_OK on success, BCS_ERR_BUFFER_TOO_SMALL if buffer is full. */
bcs_error_t bcs_write_bool(bcs_serializer_t* ser, bool value);

/* Unsigned integers */

/** @brief Serialize an unsigned 8-bit integer.
 *  @param[in,out] ser  The serializer.
 *  @param[in]     value  Value to serialize (0-255). */
bcs_error_t bcs_write_u8(bcs_serializer_t* ser, uint8_t value);

/** @brief Serialize an unsigned 16-bit integer (little-endian). */
bcs_error_t bcs_write_u16(bcs_serializer_t* ser, uint16_t value);

/** @brief Serialize an unsigned 32-bit integer (little-endian). */
bcs_error_t bcs_write_u32(bcs_serializer_t* ser, uint32_t value);

/** @brief Serialize an unsigned 64-bit integer (little-endian). */
bcs_error_t bcs_write_u64(bcs_serializer_t* ser, uint64_t value);

/** @brief Serialize an unsigned 128-bit integer (little-endian byte array).
 *  @param[in,out] ser  The serializer.
 *  @param[in]     value  16-byte little-endian representation. */
bcs_error_t bcs_write_u128(bcs_serializer_t* ser, const uint8_t value[16]);

/** @brief Serialize an unsigned 256-bit integer (little-endian byte array).
 *  @param[in,out] ser  The serializer.
 *  @param[in]     value  32-byte little-endian representation. */
bcs_error_t bcs_write_u256(bcs_serializer_t* ser, const uint8_t value[32]);

/* Signed integers (two's complement) */

/** @brief Serialize a signed 8-bit integer. */
bcs_error_t bcs_write_i8(bcs_serializer_t* ser, int8_t value);
/** @brief Serialize a signed 16-bit integer (little-endian, two's complement). */
bcs_error_t bcs_write_i16(bcs_serializer_t* ser, int16_t value);
/** @brief Serialize a signed 32-bit integer (little-endian, two's complement). */
bcs_error_t bcs_write_i32(bcs_serializer_t* ser, int32_t value);
/** @brief Serialize a signed 64-bit integer (little-endian, two's complement). */
bcs_error_t bcs_write_i64(bcs_serializer_t* ser, int64_t value);

/** @brief Serialize a signed 128-bit integer (little-endian, two's complement).
 *  @param[in,out] ser  The serializer.
 *  @param[in]     value  16-byte little-endian two's complement representation. */
bcs_error_t bcs_write_i128(bcs_serializer_t* ser, const uint8_t value[16]);

/** @brief Serialize a signed 256-bit integer (little-endian, two's complement).
 *  @param[in,out] ser  The serializer.
 *  @param[in]     value  32-byte little-endian two's complement representation. */
bcs_error_t bcs_write_i256(bcs_serializer_t* ser, const uint8_t value[32]);

/* ULEB128 */

/**
 * @brief Serialize a ULEB128-encoded unsigned integer.
 * @param[in,out] ser  The serializer.
 * @param[in]     value  Value to encode (0 to 2^32-1).
 * @return BCS_OK on success.
 */
bcs_error_t bcs_write_uleb128(bcs_serializer_t* ser, uint32_t value);

/* Bytes and strings */

/**
 * @brief Serialize fixed-length bytes (no length prefix).
 * @param[in,out] ser   The serializer.
 * @param[in]     data  Bytes to write.
 * @param[in]     len   Number of bytes.
 * @return BCS_OK on success, BCS_ERR_BUFFER_TOO_SMALL if buffer is full.
 */
bcs_error_t bcs_write_fixed_bytes(bcs_serializer_t* ser, const uint8_t* data,
                                  size_t len);

/**
 * @brief Serialize a byte array with ULEB128 length prefix.
 * @param[in,out] ser   The serializer.
 * @param[in]     data  Bytes to write.
 * @param[in]     len   Number of bytes.
 * @return BCS_OK on success, BCS_ERR_EXCEEDED_MAX_LENGTH if len exceeds limit.
 */
bcs_error_t bcs_write_bytes(bcs_serializer_t* ser, const uint8_t* data, size_t len);

/**
 * @brief Serialize a null-terminated UTF-8 string with ULEB128 length prefix.
 * @param[in,out] ser  The serializer.
 * @param[in]     str  Null-terminated UTF-8 string.
 * @return BCS_OK on success, BCS_ERR_INVALID_UTF8 if not valid UTF-8.
 */
bcs_error_t bcs_write_string(bcs_serializer_t* ser, const char* str);

/**
 * @brief Serialize a UTF-8 string of known length with ULEB128 length prefix.
 * @param[in,out] ser  The serializer.
 * @param[in]     str  UTF-8 string (need not be null-terminated).
 * @param[in]     len  Number of bytes in @p str.
 * @return BCS_OK on success, BCS_ERR_INVALID_UTF8 if not valid UTF-8.
 */
bcs_error_t bcs_write_string_n(bcs_serializer_t* ser, const char* str, size_t len);

/* Container depth tracking */

/**
 * @brief Enter a struct container for depth tracking.
 * @param[in,out] ser  The serializer.
 * @return BCS_OK on success, BCS_ERR_EXCEEDED_CONTAINER_DEPTH if too deep.
 */
bcs_error_t bcs_enter_struct(bcs_serializer_t* ser);

/** @brief Leave a struct container. */
bcs_error_t bcs_leave_struct(bcs_serializer_t* ser);

/**
 * @brief Write an enum variant index (ULEB128) and enter enum container.
 * @param[in,out] ser    The serializer.
 * @param[in]     index  Zero-based variant index.
 * @return BCS_OK on success.
 */
bcs_error_t bcs_write_variant_index(bcs_serializer_t* ser, uint32_t index);

/** @brief Leave an enum container. */
bcs_error_t bcs_leave_enum(bcs_serializer_t* ser);

/* Options */

/** @brief Write a None option tag (0x00). */
bcs_error_t bcs_write_option_none(bcs_serializer_t* ser);

/** @brief Write a Some option tag (0x01). Caller must then write the value. */
bcs_error_t bcs_write_option_some(bcs_serializer_t* ser);

/* Vectors */

/**
 * @brief Write a vector length prefix (ULEB128). Caller then writes elements.
 * @param[in,out] ser  The serializer.
 * @param[in]     len  Number of elements in the vector.
 * @return BCS_OK on success, BCS_ERR_EXCEEDED_MAX_LENGTH if @p len exceeds limit.
 */
bcs_error_t bcs_write_vector_len(bcs_serializer_t* ser, size_t len);

/* Maps */

/**
 * @brief Write a map length prefix (ULEB128). Caller then writes sorted key/value
 * pairs.
 * @param[in,out] ser  The serializer.
 * @param[in]     len  Number of entries in the map.
 * @return BCS_OK on success, BCS_ERR_EXCEEDED_MAX_LENGTH if @p len exceeds limit.
 */
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

/**
 * @brief Initialize a deserializer with input data.
 * @param[out] des   Deserializer to initialize.
 * @param[in]  data  Input data (not copied; must remain valid).
 * @param[in]  size  Length of @p data in bytes.
 * @return BCS_OK on success, BCS_ERR_NULL_POINTER if @p des or @p data is NULL.
 */
bcs_error_t bcs_deserializer_init(bcs_deserializer_t* des, const uint8_t* data,
                                  size_t size);

/**
 * @brief Verify that all input has been consumed.
 * @param[in] des  The deserializer.
 * @return BCS_OK if all bytes were read, BCS_ERR_REMAINING_INPUT otherwise.
 */
bcs_error_t bcs_check_end(const bcs_deserializer_t* des);

/**
 * @brief Get the number of remaining unread bytes.
 * @param[in] des  The deserializer.
 * @return Number of bytes remaining.
 */
size_t bcs_remaining(const bcs_deserializer_t* des);

/* Boolean */

/**
 * @brief Deserialize a boolean value.
 * @param[in,out] des    The deserializer.
 * @param[out]    value  Receives the boolean value.
 * @return BCS_OK on success, BCS_ERR_UNEXPECTED_EOF or BCS_ERR_INVALID_BOOLEAN.
 */
bcs_error_t bcs_read_bool(bcs_deserializer_t* des, bool* value);

/* Unsigned integers */

/** @brief Deserialize an unsigned 8-bit integer.
 *  @param[in,out] des    The deserializer.
 *  @param[out]    value  Receives the deserialized value. */
bcs_error_t bcs_read_u8(bcs_deserializer_t* des, uint8_t* value);
/** @brief Deserialize an unsigned 16-bit integer (little-endian). */
bcs_error_t bcs_read_u16(bcs_deserializer_t* des, uint16_t* value);
/** @brief Deserialize an unsigned 32-bit integer (little-endian). */
bcs_error_t bcs_read_u32(bcs_deserializer_t* des, uint32_t* value);
/** @brief Deserialize an unsigned 64-bit integer (little-endian). */
bcs_error_t bcs_read_u64(bcs_deserializer_t* des, uint64_t* value);

/** @brief Deserialize an unsigned 128-bit integer into a 16-byte little-endian buffer.
 *  @param[in,out] des    The deserializer.
 *  @param[out]    value  16-byte buffer to receive the value. */
bcs_error_t bcs_read_u128(bcs_deserializer_t* des, uint8_t value[16]);

/** @brief Deserialize an unsigned 256-bit integer into a 32-byte little-endian buffer.
 *  @param[in,out] des    The deserializer.
 *  @param[out]    value  32-byte buffer to receive the value. */
bcs_error_t bcs_read_u256(bcs_deserializer_t* des, uint8_t value[32]);

/* Signed integers (two's complement) */

/** @brief Deserialize a signed 8-bit integer. */
bcs_error_t bcs_read_i8(bcs_deserializer_t* des, int8_t* value);
/** @brief Deserialize a signed 16-bit integer (little-endian, two's complement). */
bcs_error_t bcs_read_i16(bcs_deserializer_t* des, int16_t* value);
/** @brief Deserialize a signed 32-bit integer (little-endian, two's complement). */
bcs_error_t bcs_read_i32(bcs_deserializer_t* des, int32_t* value);
/** @brief Deserialize a signed 64-bit integer (little-endian, two's complement). */
bcs_error_t bcs_read_i64(bcs_deserializer_t* des, int64_t* value);
/** @brief Deserialize a signed 128-bit integer (little-endian, two's complement). */
bcs_error_t bcs_read_i128(bcs_deserializer_t* des, uint8_t value[16]);
/** @brief Deserialize a signed 256-bit integer (little-endian, two's complement). */
bcs_error_t bcs_read_i256(bcs_deserializer_t* des, uint8_t value[32]);

/* ULEB128 */

/**
 * @brief Deserialize a ULEB128-encoded unsigned integer.
 * @param[in,out] des    The deserializer.
 * @param[out]    value  Receives the decoded value.
 * @return BCS_OK on success, BCS_ERR_ULEB128_OVERFLOW or BCS_ERR_NON_CANONICAL_ULEB128.
 */
bcs_error_t bcs_read_uleb128(bcs_deserializer_t* des, uint32_t* value);

/* Bytes and strings */

/**
 * @brief Deserialize fixed-length bytes (no length prefix).
 * @param[in,out] des     The deserializer.
 * @param[out]    buffer  Buffer to receive the bytes.
 * @param[in]     len     Exact number of bytes to read.
 * @return BCS_OK on success, BCS_ERR_UNEXPECTED_EOF if insufficient data.
 */
bcs_error_t bcs_read_fixed_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t len);

/**
 * @brief Read the ULEB128 length prefix of a byte sequence without reading the data.
 * @param[in,out] des  The deserializer.
 * @param[out]    len  Receives the decoded length.
 * @return BCS_OK on success.
 */
bcs_error_t bcs_read_bytes_len(bcs_deserializer_t* des, size_t* len);

/**
 * @brief Deserialize a length-prefixed byte array into a caller-provided buffer.
 * @param[in,out] des          The deserializer.
 * @param[out]    buffer       Buffer to receive the bytes.
 * @param[in]     buffer_size  Capacity of @p buffer.
 * @param[out]    out_len      Receives the actual number of bytes read.
 * @return BCS_OK on success, BCS_ERR_BUFFER_TOO_SMALL if buffer is too small.
 */
bcs_error_t bcs_read_bytes(bcs_deserializer_t* des, uint8_t* buffer, size_t buffer_size,
                           size_t* out_len);

/**
 * @brief Deserialize a length-prefixed UTF-8 string into a caller-provided buffer.
 *
 * The output is null-terminated. The string is validated as UTF-8.
 *
 * @param[in,out] des          The deserializer.
 * @param[out]    buffer       Buffer to receive the string (null-terminated).
 * @param[in]     buffer_size  Capacity of @p buffer (must include space for null).
 * @param[out]    out_len      Receives the string length in bytes (excluding null).
 * @return BCS_OK on success, BCS_ERR_INVALID_UTF8 or BCS_ERR_BUFFER_TOO_SMALL.
 */
bcs_error_t bcs_read_string(bcs_deserializer_t* des, char* buffer, size_t buffer_size,
                            size_t* out_len);

/* Container depth tracking */

/** @brief Enter a struct container for depth tracking during deserialization.
 *  @return BCS_OK on success, BCS_ERR_EXCEEDED_CONTAINER_DEPTH if too deep. */
bcs_error_t bcs_des_enter_struct(bcs_deserializer_t* des);
/** @brief Leave a struct container during deserialization. */
bcs_error_t bcs_des_leave_struct(bcs_deserializer_t* des);

/**
 * @brief Read an enum variant index (ULEB128) and enter enum container.
 * @param[in,out] des    The deserializer.
 * @param[out]    index  Receives the zero-based variant index.
 * @return BCS_OK on success.
 */
bcs_error_t bcs_read_variant_index(bcs_deserializer_t* des, uint32_t* index);
/** @brief Leave an enum container during deserialization. */
bcs_error_t bcs_des_leave_enum(bcs_deserializer_t* des);

/* Options */

/**
 * @brief Read an option tag (0x00 = None, 0x01 = Some).
 * @param[in,out] des      The deserializer.
 * @param[out]    is_some  Receives true if the option contains a value.
 * @return BCS_OK on success, BCS_ERR_INVALID_OPTION if tag is not 0 or 1.
 */
bcs_error_t bcs_read_option_tag(bcs_deserializer_t* des, bool* is_some);

/* Vectors */

/**
 * @brief Read a vector length prefix (ULEB128).
 * @param[in,out] des  The deserializer.
 * @param[out]    len  Receives the number of elements.
 * @return BCS_OK on success, BCS_ERR_EXCEEDED_MAX_LENGTH if length exceeds limit.
 */
bcs_error_t bcs_read_vector_len(bcs_deserializer_t* des, size_t* len);

/* Maps */

/**
 * @brief Read a map length prefix (ULEB128).
 * @param[in,out] des  The deserializer.
 * @param[out]    len  Receives the number of entries.
 * @return BCS_OK on success.
 */
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

/**
 * @brief Encode a u32 value as ULEB128.
 * @param[in]  value        Value to encode.
 * @param[out] buffer       Output buffer (must be at least BCS_ULEB128_MAX_BYTES).
 * @param[in]  buffer_size  Capacity of @p buffer.
 * @return Number of bytes written, or 0 if @p buffer_size is insufficient.
 */
size_t bcs_uleb128_encode(uint32_t value, uint8_t* buffer, size_t buffer_size);

/**
 * @brief Decode a ULEB128-encoded value.
 * @param[in]  data   Input data.
 * @param[in]  size   Length of @p data in bytes.
 * @param[out] value  Receives the decoded u32 value.
 * @param[out] err    Receives the error code (BCS_OK on success).
 * @return Number of bytes consumed, or 0 on error.
 */
size_t bcs_uleb128_decode(const uint8_t* data, size_t size, uint32_t* value,
                          bcs_error_t* err);

/**
 * @brief Get the number of bytes needed to encode a value as ULEB128.
 * @param[in] value  The value to encode.
 * @return Number of bytes (1-5).
 */
size_t bcs_uleb128_encoded_size(uint32_t value);

/* ============================================================================
 * UTILITIES
 * ============================================================================ */

/**
 * @brief Validate that a byte sequence is valid UTF-8.
 * @param[in] data  Bytes to validate.
 * @param[in] len   Length in bytes.
 * @return true if valid UTF-8, false otherwise.
 */
bool bcs_is_valid_utf8(const uint8_t* data, size_t len);

/**
 * @brief Convert a byte array to a lowercase hex string.
 * @param[in]  bytes        Input bytes.
 * @param[in]  len          Number of input bytes.
 * @param[out] hex_buffer   Buffer for hex output (must hold at least 2*len + 1).
 * @param[in]  buffer_size  Capacity of @p hex_buffer.
 * @return Number of hex characters written (excluding null terminator), or 0 on error.
 */
size_t bcs_bytes_to_hex(const uint8_t* bytes, size_t len, char* hex_buffer,
                        size_t buffer_size);

/**
 * @brief Convert a hex string to bytes.
 * @param[in]  hex          Null-terminated hex string (lowercase or uppercase).
 * @param[out] buffer       Output buffer for decoded bytes.
 * @param[in]  buffer_size  Capacity of @p buffer.
 * @return Number of bytes written, or 0 on error (odd length, invalid chars, etc.).
 */
size_t bcs_hex_to_bytes(const char* hex, uint8_t* buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif

#endif /* BCS_H */
