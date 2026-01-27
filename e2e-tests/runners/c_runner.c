// C BCS E2E Test Runner
// Compile: gcc -std=c99 -O2 -o c_runner c_runner.c

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>

// BCS Serializer
typedef struct {
    uint8_t *buffer;
    size_t capacity;
    size_t size;
} BcsSerializer;

void ser_init(BcsSerializer *s) {
    s->capacity = 1024;
    s->buffer = malloc(s->capacity);
    s->size = 0;
}

void ser_free(BcsSerializer *s) { free(s->buffer); }

void ser_ensure(BcsSerializer *s, size_t need) {
    if (s->size + need > s->capacity) {
        s->capacity = (s->size + need) * 2;
        s->buffer = realloc(s->buffer, s->capacity);
    }
}

void ser_write_u8(BcsSerializer *s, uint8_t v) { ser_ensure(s, 1); s->buffer[s->size++] = v; }
void ser_write_bool(BcsSerializer *s, bool v) { ser_write_u8(s, v ? 1 : 0); }
void ser_write_u16(BcsSerializer *s, uint16_t v) { ser_write_u8(s, v & 0xFF); ser_write_u8(s, (v >> 8) & 0xFF); }
void ser_write_u32(BcsSerializer *s, uint32_t v) { for (int i = 0; i < 4; i++) ser_write_u8(s, (v >> (i * 8)) & 0xFF); }
void ser_write_u64(BcsSerializer *s, uint64_t v) { for (int i = 0; i < 8; i++) ser_write_u8(s, (v >> (i * 8)) & 0xFF); }
void ser_write_u128(BcsSerializer *s, const uint8_t *v) { ser_ensure(s, 16); memcpy(s->buffer + s->size, v, 16); s->size += 16; }
void ser_write_i8(BcsSerializer *s, int8_t v) { ser_write_u8(s, (uint8_t)v); }
void ser_write_i16(BcsSerializer *s, int16_t v) { ser_write_u16(s, (uint16_t)v); }
void ser_write_i32(BcsSerializer *s, int32_t v) { ser_write_u32(s, (uint32_t)v); }
void ser_write_i64(BcsSerializer *s, int64_t v) { ser_write_u64(s, (uint64_t)v); }
void ser_write_i128(BcsSerializer *s, const uint8_t *v) { ser_write_u128(s, v); }

void ser_write_uleb128(BcsSerializer *s, uint32_t v) {
    do {
        uint8_t b = v & 0x7F;
        v >>= 7;
        if (v != 0) b |= 0x80;
        ser_write_u8(s, b);
    } while (v != 0);
}

void ser_write_bytes(BcsSerializer *s, const uint8_t *data, size_t len) {
    ser_write_uleb128(s, len);
    ser_ensure(s, len);
    memcpy(s->buffer + s->size, data, len);
    s->size += len;
}

void ser_write_fixed_bytes(BcsSerializer *s, const uint8_t *data, size_t len) {
    ser_ensure(s, len);
    memcpy(s->buffer + s->size, data, len);
    s->size += len;
}

void ser_write_string(BcsSerializer *s, const char *str) {
    size_t len = strlen(str);
    ser_write_uleb128(s, len);
    ser_ensure(s, len);
    memcpy(s->buffer + s->size, str, len);
    s->size += len;
}

// BCS Deserializer
typedef struct {
    const uint8_t *data;
    size_t size;
    size_t offset;
    char error[256];
} BcsDeserializer;

void des_init(BcsDeserializer *d, const uint8_t *data, size_t size) {
    d->data = data;
    d->size = size;
    d->offset = 0;
    d->error[0] = '\0';
}

bool des_read_u8(BcsDeserializer *d, uint8_t *v) {
    if (d->offset >= d->size) { strcpy(d->error, "EOF"); return false; }
    *v = d->data[d->offset++];
    return true;
}

bool des_read_bool(BcsDeserializer *d, bool *v) {
    uint8_t b;
    if (!des_read_u8(d, &b)) return false;
    if (b != 0 && b != 1) { strcpy(d->error, "Invalid bool"); return false; }
    *v = b == 1;
    return true;
}

bool des_read_u16(BcsDeserializer *d, uint16_t *v) {
    if (d->offset + 2 > d->size) { strcpy(d->error, "EOF"); return false; }
    *v = d->data[d->offset] | (d->data[d->offset + 1] << 8);
    d->offset += 2;
    return true;
}

bool des_read_u32(BcsDeserializer *d, uint32_t *v) {
    if (d->offset + 4 > d->size) { strcpy(d->error, "EOF"); return false; }
    *v = 0;
    for (int i = 0; i < 4; i++) *v |= (uint32_t)d->data[d->offset + i] << (i * 8);
    d->offset += 4;
    return true;
}

bool des_read_u64(BcsDeserializer *d, uint64_t *v) {
    if (d->offset + 8 > d->size) { strcpy(d->error, "EOF"); return false; }
    *v = 0;
    for (int i = 0; i < 8; i++) *v |= (uint64_t)d->data[d->offset + i] << (i * 8);
    d->offset += 8;
    return true;
}

bool des_read_u128(BcsDeserializer *d, uint8_t *v) {
    if (d->offset + 16 > d->size) { strcpy(d->error, "EOF"); return false; }
    memcpy(v, d->data + d->offset, 16);
    d->offset += 16;
    return true;
}

bool des_read_i8(BcsDeserializer *d, int8_t *v) { return des_read_u8(d, (uint8_t*)v); }
bool des_read_i16(BcsDeserializer *d, int16_t *v) { return des_read_u16(d, (uint16_t*)v); }
bool des_read_i32(BcsDeserializer *d, int32_t *v) { return des_read_u32(d, (uint32_t*)v); }
bool des_read_i64(BcsDeserializer *d, int64_t *v) { return des_read_u64(d, (uint64_t*)v); }
bool des_read_i128(BcsDeserializer *d, uint8_t *v) { return des_read_u128(d, v); }

bool des_read_uleb128(BcsDeserializer *d, uint32_t *v) {
    *v = 0;
    int shift = 0;
    while (1) {
        if (d->offset >= d->size) { strcpy(d->error, "EOF"); return false; }
        uint8_t b = d->data[d->offset++];
        *v |= (b & 0x7F) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
    }
    return true;
}

bool des_read_bytes(BcsDeserializer *d, uint8_t **v, uint32_t *len) {
    if (!des_read_uleb128(d, len)) return false;
    if (d->offset + *len > d->size) { strcpy(d->error, "EOF"); return false; }
    *v = malloc(*len);
    memcpy(*v, d->data + d->offset, *len);
    d->offset += *len;
    return true;
}

bool des_read_fixed_bytes(BcsDeserializer *d, uint8_t *v, size_t len) {
    if (d->offset + len > d->size) { strcpy(d->error, "EOF"); return false; }
    memcpy(v, d->data + d->offset, len);
    d->offset += len;
    return true;
}

bool des_read_string(BcsDeserializer *d, char **v) {
    uint32_t len;
    if (!des_read_uleb128(d, &len)) return false;
    if (d->offset + len > d->size) { strcpy(d->error, "EOF"); return false; }
    *v = malloc(len + 1);
    memcpy(*v, d->data + d->offset, len);
    (*v)[len] = '\0';
    d->offset += len;
    return true;
}

bool des_check_end(BcsDeserializer *d) {
    if (d->offset != d->size) { strcpy(d->error, "Remaining input"); return false; }
    return true;
}

// Hex conversion
size_t hex_to_bytes(const char *hex, uint8_t *out) {
    size_t len = strlen(hex) / 2;
    for (size_t i = 0; i < len; i++) {
        char byte[3] = {hex[i*2], hex[i*2+1], '\0'};
        out[i] = (uint8_t)strtol(byte, NULL, 16);
    }
    return len;
}

void bytes_to_hex(const uint8_t *data, size_t len, char *out) {
    for (size_t i = 0; i < len; i++) sprintf(out + i*2, "%02x", data[i]);
    out[len*2] = '\0';
}

// JSON helpers - find a string value for a key
char *find_json_string(const char *json, const char *key, char *out, size_t max_len) {
    char search[256];
    sprintf(search, "\"%s\"", key);
    const char *pos = strstr(json, search);
    if (!pos) return NULL;
    pos += strlen(search);
    while (*pos && (*pos == ' ' || *pos == ':' || *pos == '\t' || *pos == '\n' || *pos == '\r')) pos++;
    if (*pos != '"') return NULL;
    pos++;
    size_t i = 0;
    while (*pos && *pos != '"' && i < max_len - 1) {
        if (*pos == '\\' && *(pos+1)) {
            pos++;
            if (*pos == 'n') out[i++] = '\n';
            else if (*pos == 'r') out[i++] = '\r';
            else if (*pos == 't') out[i++] = '\t';
            else if (*pos == 'u') {
                // Unicode escape - skip for now, just put placeholder
                pos += 4;
                out[i++] = '?';
                continue;
            }
            else out[i++] = *pos;
        } else {
            out[i++] = *pos;
        }
        pos++;
    }
    out[i] = '\0';
    return out;
}

// Find value JSON - handles objects, arrays, strings, numbers, bools, null
const char *find_json_value(const char *json, const char *key, char *out, size_t max_len) {
    char search[256];
    sprintf(search, "\"%s\"", key);
    const char *pos = strstr(json, search);
    if (!pos) { strcpy(out, "null"); return out; }
    pos += strlen(search);
    while (*pos && (*pos == ' ' || *pos == ':' || *pos == '\t' || *pos == '\n' || *pos == '\r')) pos++;
    
    const char *start = pos;
    int depth = 0;
    bool in_str = false;
    
    while (*pos) {
        char c = *pos;
        if (in_str) {
            if (c == '\\' && *(pos+1)) pos++;
            else if (c == '"') in_str = false;
        } else {
            if (c == '"') in_str = true;
            else if (c == '{' || c == '[') depth++;
            else if (c == '}' || c == ']') {
                if (depth == 0) break;
                depth--;
            }
            else if ((c == ',' || c == '\n') && depth == 0) break;
        }
        pos++;
    }
    
    size_t len = pos - start;
    if (len >= max_len) len = max_len - 1;
    strncpy(out, start, len);
    out[len] = '\0';
    
    // Trim trailing whitespace
    while (len > 0 && (out[len-1] == ' ' || out[len-1] == '\t' || out[len-1] == '\n' || out[len-1] == '\r')) {
        out[--len] = '\0';
    }
    
    return out;
}

// Process a single test case - just do roundtrip based on type
void process_test(const char *name, const char *type, const char *bcs_hex, const char *value_json, FILE *out, int is_last) {
    uint8_t data[2048];
    size_t data_len = hex_to_bytes(bcs_hex, data);
    
    BcsDeserializer d;
    des_init(&d, data, data_len);
    BcsSerializer s;
    ser_init(&s);
    
    char result_hex[4096] = "";
    char error[256] = "";
    
    #define ROUNDTRIP(t, read_fn, write_fn) do { \
        t v; \
        if (!read_fn(&d, &v)) { strcpy(error, d.error); goto done; } \
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; } \
        write_fn(&s, v); \
        bytes_to_hex(s.buffer, s.size, result_hex); \
    } while(0)
    
    if (strcmp(type, "bool") == 0) { ROUNDTRIP(bool, des_read_bool, ser_write_bool); }
    else if (strcmp(type, "u8") == 0) { ROUNDTRIP(uint8_t, des_read_u8, ser_write_u8); }
    else if (strcmp(type, "u16") == 0) { ROUNDTRIP(uint16_t, des_read_u16, ser_write_u16); }
    else if (strcmp(type, "u32") == 0) { ROUNDTRIP(uint32_t, des_read_u32, ser_write_u32); }
    else if (strcmp(type, "u64") == 0) { ROUNDTRIP(uint64_t, des_read_u64, ser_write_u64); }
    else if (strcmp(type, "i8") == 0) { ROUNDTRIP(int8_t, des_read_i8, ser_write_i8); }
    else if (strcmp(type, "i16") == 0) { ROUNDTRIP(int16_t, des_read_i16, ser_write_i16); }
    else if (strcmp(type, "i32") == 0) { ROUNDTRIP(int32_t, des_read_i32, ser_write_i32); }
    else if (strcmp(type, "i64") == 0) { ROUNDTRIP(int64_t, des_read_i64, ser_write_i64); }
    else if (strcmp(type, "u128") == 0) {
        uint8_t v[16];
        if (!des_read_u128(&d, v)) { strcpy(error, d.error); goto done; }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        ser_write_u128(&s, v);
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "i128") == 0) {
        uint8_t v[16];
        if (!des_read_i128(&d, v)) { strcpy(error, d.error); goto done; }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        ser_write_i128(&s, v);
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "string") == 0) {
        char *v;
        if (!des_read_string(&d, &v)) { strcpy(error, d.error); goto done; }
        if (!des_check_end(&d)) { free(v); strcpy(error, d.error); goto done; }
        ser_write_string(&s, v);
        bytes_to_hex(s.buffer, s.size, result_hex);
        free(v);
    }
    else if (strcmp(type, "bytes") == 0) {
        uint8_t *v; uint32_t len;
        if (!des_read_bytes(&d, &v, &len)) { strcpy(error, d.error); goto done; }
        if (!des_check_end(&d)) { free(v); strcpy(error, d.error); goto done; }
        ser_write_bytes(&s, v, len);
        bytes_to_hex(s.buffer, s.size, result_hex);
        free(v);
    }
    else if (strcmp(type, "fixed_bytes_32") == 0) {
        uint8_t v[32];
        if (!des_read_fixed_bytes(&d, v, 32)) { strcpy(error, d.error); goto done; }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        ser_write_fixed_bytes(&s, v, 32);
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "option<u8>") == 0) {
        bool has; if (!des_read_bool(&d, &has)) { strcpy(error, d.error); goto done; }
        ser_write_bool(&s, has);
        if (has) { uint8_t v; if (!des_read_u8(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_u8(&s, v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "option<u64>") == 0) {
        bool has; if (!des_read_bool(&d, &has)) { strcpy(error, d.error); goto done; }
        ser_write_bool(&s, has);
        if (has) { uint64_t v; if (!des_read_u64(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_u64(&s, v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "option<bool>") == 0) {
        bool has; if (!des_read_bool(&d, &has)) { strcpy(error, d.error); goto done; }
        ser_write_bool(&s, has);
        if (has) { bool v; if (!des_read_bool(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_bool(&s, v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "option<string>") == 0) {
        bool has; if (!des_read_bool(&d, &has)) { strcpy(error, d.error); goto done; }
        ser_write_bool(&s, has);
        if (has) { char *v; if (!des_read_string(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_string(&s, v); free(v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "vector<u8>") == 0) {
        uint32_t len; if (!des_read_uleb128(&d, &len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, len);
        for (uint32_t i = 0; i < len; i++) { uint8_t v; if (!des_read_u8(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_u8(&s, v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "vector<u64>") == 0) {
        uint32_t len; if (!des_read_uleb128(&d, &len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, len);
        for (uint32_t i = 0; i < len; i++) { uint64_t v; if (!des_read_u64(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_u64(&s, v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "vector<bool>") == 0) {
        uint32_t len; if (!des_read_uleb128(&d, &len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, len);
        for (uint32_t i = 0; i < len; i++) { bool v; if (!des_read_bool(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_bool(&s, v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "vector<vector<u8>>") == 0) {
        uint32_t outer_len; if (!des_read_uleb128(&d, &outer_len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, outer_len);
        for (uint32_t i = 0; i < outer_len; i++) {
            uint32_t inner_len; if (!des_read_uleb128(&d, &inner_len)) { strcpy(error, d.error); goto done; }
            ser_write_uleb128(&s, inner_len);
            for (uint32_t j = 0; j < inner_len; j++) { uint8_t v; if (!des_read_u8(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_u8(&s, v); }
        }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "vector<string>") == 0) {
        uint32_t len; if (!des_read_uleb128(&d, &len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, len);
        for (uint32_t i = 0; i < len; i++) { char *v; if (!des_read_string(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_string(&s, v); free(v); }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "struct") == 0) {
        // Parse fields from value_json - look for field objects in the "fields" array
        const char *fields = strstr(value_json, "\"fields\"");
        if (fields) {
            const char *arr_start = strchr(fields, '[');
            if (arr_start) {
                const char *pos = arr_start + 1;
                int arr_depth = 1;
                int obj_depth = 0;
                bool in_str = false;
                
                while (*pos && arr_depth > 0) {
                    char c = *pos;
                    if (in_str) {
                        if (c == '"' && *(pos-1) != '\\') in_str = false;
                        pos++;
                        continue;
                    }
                    if (c == '"') { in_str = true; pos++; continue; }
                    
                    if (c == '[') { arr_depth++; pos++; continue; }
                    if (c == ']') { arr_depth--; pos++; continue; }
                    
                    // Look for field object at the right depth
                    if (c == '{' && arr_depth == 1 && obj_depth == 0) {
                        // Found a field object - extract its type
                        const char *field_start = pos;
                        int fd = 1;
                        pos++;
                        while (*pos && fd > 0) {
                            if (*pos == '"' && *(pos-1) != '\\') {
                                pos++;
                                while (*pos && !(*pos == '"' && *(pos-1) != '\\')) pos++;
                            }
                            else if (*pos == '{') fd++;
                            else if (*pos == '}') fd--;
                            pos++;
                        }
                        // Now extract type from field_start to pos
                        const char *type_key = strstr(field_start, "\"type\"");
                        if (type_key && type_key < pos) {
                            const char *ts = strchr(type_key + 6, '"');
                            if (ts && ts < pos) {
                                ts++;
                                const char *te = strchr(ts, '"');
                                if (te && te < pos) {
                                    char field_type[64];
                                    size_t ft_len = te - ts;
                                    if (ft_len < sizeof(field_type)) {
                                        strncpy(field_type, ts, ft_len);
                                        field_type[ft_len] = '\0';
                                        
                                        if (strcmp(field_type, "u8") == 0) { uint8_t v; des_read_u8(&d, &v); ser_write_u8(&s, v); }
                                        else if (strcmp(field_type, "u64") == 0) { uint64_t v; des_read_u64(&d, &v); ser_write_u64(&s, v); }
                                        else if (strcmp(field_type, "string") == 0) { char *v; des_read_string(&d, &v); ser_write_string(&s, v); free(v); }
                                        else if (strcmp(field_type, "fixed_bytes_32") == 0) { uint8_t v[32]; des_read_fixed_bytes(&d, v, 32); ser_write_fixed_bytes(&s, v, 32); }
                                    }
                                }
                            }
                        }
                        continue;
                    }
                    
                    if (c == '{') obj_depth++;
                    else if (c == '}') obj_depth--;
                    pos++;
                }
            }
        }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "map<u8,u8>") == 0) {
        uint32_t len; if (!des_read_uleb128(&d, &len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, len);
        for (uint32_t i = 0; i < len; i++) {
            uint8_t k, v;
            if (!des_read_u8(&d, &k)) { strcpy(error, d.error); goto done; }
            if (!des_read_u8(&d, &v)) { strcpy(error, d.error); goto done; }
            ser_write_u8(&s, k); ser_write_u8(&s, v);
        }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "map<string,u64>") == 0) {
        uint32_t len; if (!des_read_uleb128(&d, &len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, len);
        for (uint32_t i = 0; i < len; i++) {
            char *k; uint64_t v;
            if (!des_read_string(&d, &k)) { strcpy(error, d.error); goto done; }
            if (!des_read_u64(&d, &v)) { free(k); strcpy(error, d.error); goto done; }
            ser_write_string(&s, k); ser_write_u64(&s, v);
            free(k);
        }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "tuple<u8,u64>") == 0) {
        uint8_t a; uint64_t b;
        if (!des_read_u8(&d, &a)) { strcpy(error, d.error); goto done; }
        if (!des_read_u64(&d, &b)) { strcpy(error, d.error); goto done; }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        ser_write_u8(&s, a); ser_write_u64(&s, b);
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else if (strcmp(type, "vector<option<u8>>") == 0) {
        uint32_t len; if (!des_read_uleb128(&d, &len)) { strcpy(error, d.error); goto done; }
        ser_write_uleb128(&s, len);
        for (uint32_t i = 0; i < len; i++) {
            bool has; if (!des_read_bool(&d, &has)) { strcpy(error, d.error); goto done; }
            ser_write_bool(&s, has);
            if (has) { uint8_t v; if (!des_read_u8(&d, &v)) { strcpy(error, d.error); goto done; } ser_write_u8(&s, v); }
        }
        if (!des_check_end(&d)) { strcpy(error, d.error); goto done; }
        bytes_to_hex(s.buffer, s.size, result_hex);
    }
    else {
        sprintf(error, "Unknown type: %s", type);
    }
    
done:
    fprintf(out, "    {\"name\": \"%s\", \"type\": \"%s\", \"bcs_hex\": \"%s\", \"value\": %s", name, type, result_hex, value_json);
    if (error[0]) {
        fprintf(out, ", \"error\": \"%s\"", error);
    }
    fprintf(out, "}%s\n", is_last ? "" : ",");
    
    ser_free(&s);
}

// Benchmark support
static long long get_nanos(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

static int compare_ll(const void *a, const void *b) {
    long long la = *(const long long*)a;
    long long lb = *(const long long*)b;
    return (la > lb) - (la < lb);
}

static void compute_bench_stats(long long *times, int n, double *avg, double *min, double *max, double *p50, double *p95) {
    if (n == 0) { *avg = *min = *max = *p50 = *p95 = 0; return; }
    qsort(times, n, sizeof(long long), compare_ll);
    long long sum = 0;
    for (int i = 0; i < n; i++) sum += times[i];
    *avg = (double)sum / n;
    *min = (double)times[0];
    *max = (double)times[n-1];
    *p50 = (double)times[n/2];
    *p95 = (double)times[(int)(n * 0.95)];
}

static void serialize_bench_value(BcsSerializer *s, const char *type, const char *value_json) {
    if (strcmp(type, "bool") == 0) {
        ser_write_bool(s, strstr(value_json, "true") != NULL);
    } else if (strcmp(type, "u8") == 0) {
        ser_write_u8(s, (uint8_t)atoi(value_json));
    } else if (strcmp(type, "u16") == 0) {
        ser_write_u16(s, (uint16_t)atoi(value_json));
    } else if (strcmp(type, "u32") == 0) {
        ser_write_u32(s, (uint32_t)strtoul(value_json, NULL, 10));
    } else if (strcmp(type, "u64") == 0) {
        char v[64] = {0};
        strncpy(v, value_json, sizeof(v)-1);
        char *p = v; while (*p == '"') p++;
        char *e = p; while (*e && *e != '"') e++; *e = 0;
        ser_write_u64(s, strtoull(p, NULL, 10));
    } else if (strcmp(type, "string") == 0) {
        char str[4096] = {0};
        const char *start = strchr(value_json, '"');
        if (start) {
            start++;
            const char *end = strchr(start, '"');
            if (end) {
                size_t len = end - start;
                memcpy(str, start, len);
                ser_write_string(s, str);
            }
        }
    } else if (strstr(type, "vector<u8>") || strcmp(type, "bytes") == 0) {
        // Parse array of numbers
        int count = 0;
        const char *p = strchr(value_json, '[');
        if (p) {
            p++;
            uint8_t vals[4096];
            while (*p && *p != ']') {
                while (*p && (*p == ' ' || *p == ',')) p++;
                if (*p >= '0' && *p <= '9') {
                    vals[count++] = (uint8_t)atoi(p);
                    while (*p >= '0' && *p <= '9') p++;
                }
            }
            ser_write_uleb128(s, count);
            for (int i = 0; i < count; i++) ser_write_u8(s, vals[i]);
        }
    }
}

static void deserialize_bench_value(BcsDeserializer *d, const char *type) {
    if (strcmp(type, "bool") == 0) { bool v; des_read_bool(d, &v); }
    else if (strcmp(type, "u8") == 0) { uint8_t v; des_read_u8(d, &v); }
    else if (strcmp(type, "u16") == 0) { uint16_t v; des_read_u16(d, &v); }
    else if (strcmp(type, "u32") == 0) { uint32_t v; des_read_u32(d, &v); }
    else if (strcmp(type, "u64") == 0) { uint64_t v; des_read_u64(d, &v); }
    else if (strcmp(type, "string") == 0) { char *v = des_read_string(d); free(v); }
    else if (strstr(type, "vector<u8>") || strcmp(type, "bytes") == 0) {
        uint32_t len; des_read_uleb128(d, &len);
        for (uint32_t i = 0; i < len; i++) { uint8_t v; des_read_u8(d, &v); }
    }
}

static void run_benchmarks(const char *input) {
    printf("{\n  \"version\": \"1.0.0\",\n  \"description\": \"C benchmark results\",\n  \"benchmarks\": [\n");
    
    int default_iterations = 1000, warmup = 10;
    
    // Parse config
    const char *cfg = strstr(input, "\"default_iterations\"");
    if (cfg) {
        cfg = strchr(cfg, ':');
        if (cfg) default_iterations = atoi(cfg + 1);
    }
    cfg = strstr(input, "\"warmup_iterations\"");
    if (cfg) {
        cfg = strchr(cfg, ':');
        if (cfg) warmup = atoi(cfg + 1);
    }
    
    // Find scenarios
    const char *scenarios = strstr(input, "\"scenarios\"");
    if (!scenarios) { printf("  ]\n}\n"); return; }
    
    int first_result = 1;
    const char *bench = strstr(scenarios, "\"benchmarks\"");
    
    while (bench) {
        const char *arr_start = strchr(bench, '[');
        if (!arr_start) break;
        arr_start++;
        
        // Find each benchmark case
        const char *bc = strchr(arr_start, '{');
        while (bc && *bc) {
            // Parse name
            char name[256] = "", type[256] = "", value[4096] = "null";
            find_json_string(bc, "name", name, sizeof(name));
            find_json_string(bc, "type", type, sizeof(type));
            find_json_value(bc, "value", value, sizeof(value));
            
            int iterations = default_iterations;
            const char *iter_pos = strstr(bc, "\"iterations\"");
            if (iter_pos && iter_pos < strchr(bc, '}')) {
                iter_pos = strchr(iter_pos, ':');
                if (iter_pos) iterations = atoi(iter_pos + 1);
            }
            
            // Check for value_generator
            char gen[64] = "";
            find_json_string(bc, "value_generator", gen, sizeof(gen));
            if (gen[0]) {
                int len = 10;
                const char *len_pos = strstr(bc, "\"length\"");
                if (len_pos) { len_pos = strchr(len_pos, ':'); if (len_pos) len = atoi(len_pos + 1); }
                
                if (strcmp(gen, "sequential_bytes") == 0 || strcmp(gen, "sequential_u8") == 0) {
                    char *p = value;
                    *p++ = '[';
                    for (int i = 0; i < len; i++) {
                        if (i > 0) *p++ = ',';
                        p += sprintf(p, "%d", i % 256);
                    }
                    *p++ = ']'; *p = 0;
                } else if (strcmp(gen, "repeat_char") == 0) {
                    char ch = 'a';
                    const char *ch_pos = strstr(bc, "\"char\"");
                    if (ch_pos) { ch_pos = strchr(ch_pos, '"'); if (ch_pos) { ch_pos++; ch_pos = strchr(ch_pos, '"'); if (ch_pos) { ch_pos++; ch = *ch_pos; }}}
                    value[0] = '"';
                    for (int i = 0; i < len; i++) value[1+i] = ch;
                    value[1+len] = '"'; value[2+len] = 0;
                }
            }
            
            if (!first_result) printf(",\n");
            first_result = 0;
            
            // Run benchmark
            long long *ser_times = malloc(iterations * sizeof(long long));
            long long *de_times = malloc(iterations * sizeof(long long));
            
            // Serialize to get bytes
            BcsSerializer s; ser_init(&s);
            serialize_bench_value(&s, type, value);
            uint8_t *bcs_bytes = malloc(s.size);
            memcpy(bcs_bytes, s.buffer, s.size);
            size_t bcs_len = s.size;
            ser_free(&s);
            
            // Warmup serialize
            for (int i = 0; i < warmup; i++) {
                BcsSerializer ws; ser_init(&ws);
                serialize_bench_value(&ws, type, value);
                ser_free(&ws);
            }
            
            // Benchmark serialize
            for (int i = 0; i < iterations; i++) {
                long long start = get_nanos();
                BcsSerializer bs; ser_init(&bs);
                serialize_bench_value(&bs, type, value);
                ser_free(&bs);
                ser_times[i] = get_nanos() - start;
            }
            
            // Warmup deserialize
            for (int i = 0; i < warmup; i++) {
                BcsDeserializer wd; des_init(&wd, bcs_bytes, bcs_len);
                deserialize_bench_value(&wd, type);
            }
            
            // Benchmark deserialize
            for (int i = 0; i < iterations; i++) {
                long long start = get_nanos();
                BcsDeserializer bd; des_init(&bd, bcs_bytes, bcs_len);
                deserialize_bench_value(&bd, type);
                de_times[i] = get_nanos() - start;
            }
            
            double ser_avg, ser_min, ser_max, ser_p50, ser_p95;
            double de_avg, de_min, de_max, de_p50, de_p95;
            compute_bench_stats(ser_times, iterations, &ser_avg, &ser_min, &ser_max, &ser_p50, &ser_p95);
            compute_bench_stats(de_times, iterations, &de_avg, &de_min, &de_max, &de_p50, &de_p95);
            
            printf("    {\"name\": \"%s\", \"type\": \"%s\", \"iterations\": %d, ", name, type, iterations);
            printf("\"serialize_avg_ns\": %.2f, \"serialize_min_ns\": %.2f, \"serialize_max_ns\": %.2f, ", ser_avg, ser_min, ser_max);
            printf("\"serialize_p50_ns\": %.2f, \"serialize_p95_ns\": %.2f, ", ser_p50, ser_p95);
            printf("\"deserialize_avg_ns\": %.2f, \"deserialize_min_ns\": %.2f, \"deserialize_max_ns\": %.2f, ", de_avg, de_min, de_max);
            printf("\"deserialize_p50_ns\": %.2f, \"deserialize_p95_ns\": %.2f, ", de_p50, de_p95);
            printf("\"throughput_serialize_ops_sec\": %.2f, ", ser_avg > 0 ? 1e9/ser_avg : 0);
            printf("\"throughput_deserialize_ops_sec\": %.2f}", de_avg > 0 ? 1e9/de_avg : 0);
            
            free(ser_times);
            free(de_times);
            free(bcs_bytes);
            
            // Move to next benchmark case
            bc = strchr(bc + 1, '{');
            if (bc) {
                // Check if we've exited the benchmarks array
                const char *arr_end = strchr(arr_start, ']');
                if (arr_end && bc > arr_end) break;
            }
        }
        
        // Find next benchmarks array
        bench = strstr(bench + 1, "\"benchmarks\"");
    }
    
    printf("\n  ]\n}\n");
}

// Extract test cases and process them
void process_category(const char *input, const char *category, FILE *out, int is_last_cat) {
    fprintf(out, "  \"%s\": [\n", category);
    
    // Find category array
    char search[64];
    sprintf(search, "\"%s\"", category);
    const char *cat_pos = strstr(input, search);
    
    if (cat_pos) {
        const char *arr_start = strchr(cat_pos, '[');
        if (arr_start) {
            arr_start++;
            
            // Count test cases first - must track both array and object depth
            int tc_count = 0;
            int arr_depth = 1;
            int obj_depth = 0;
            bool in_str = false;
            const char *pos = arr_start;
            while (*pos && arr_depth > 0) {
                char c = *pos;
                if (in_str) {
                    if (c == '"' && *(pos-1) != '\\') in_str = false;
                } else {
                    if (c == '"') in_str = true;
                    else if (c == '[') arr_depth++;
                    else if (c == ']') arr_depth--;
                    else if (c == '{') {
                        if (arr_depth == 1 && obj_depth == 0) tc_count++;
                        obj_depth++;
                    }
                    else if (c == '}') obj_depth--;
                }
                pos++;
            }
            
            // Process test cases
            pos = arr_start;
            arr_depth = 1;
            obj_depth = 0;
            in_str = false;
            int tc_idx = 0;
            
            while (*pos && arr_depth > 0) {
                char c = *pos;
                if (in_str) {
                    if (c == '"' && (pos == arr_start || *(pos-1) != '\\')) in_str = false;
                    pos++;
                    continue;
                }
                if (c == '"') { in_str = true; pos++; continue; }
                
                if (c == '{' && arr_depth == 1 && obj_depth == 0) {
                    const char *tc_start = pos;
                    int obj_depth = 1;
                    pos++;
                    while (*pos && obj_depth > 0) {
                        if (*pos == '"') {
                            pos++;
                            while (*pos && !(*pos == '"' && *(pos-1) != '\\')) pos++;
                        }
                        else if (*pos == '{') obj_depth++;
                        else if (*pos == '}') obj_depth--;
                        pos++;
                    }
                    
                    // Extract test case fields
                    size_t tc_len = pos - tc_start;
                    char *tc_json = malloc(tc_len + 1);
                    memcpy(tc_json, tc_start, tc_len);
                    tc_json[tc_len] = '\0';
                    
                    char name[256] = "", type[256] = "", bcs_hex[4096] = "";
                    char value_json[8192] = "null";
                    
                    find_json_string(tc_json, "name", name, sizeof(name));
                    find_json_string(tc_json, "type", type, sizeof(type));
                    find_json_string(tc_json, "bcs_hex", bcs_hex, sizeof(bcs_hex));
                    find_json_value(tc_json, "value", value_json, sizeof(value_json));
                    
                    tc_idx++;
                    process_test(name, type, bcs_hex, value_json, out, tc_idx == tc_count);
                    
                    free(tc_json);
                    continue;
                }
                if (c == '[') arr_depth++;
                else if (c == ']') arr_depth--;
                else if (c == '{') obj_depth++;
                else if (c == '}') obj_depth--;
                pos++;
            }
        }
    }
    
    fprintf(out, "  ]%s\n", is_last_cat ? "" : ",");
}

int main(int argc, char *argv[]) {
    // Check for benchmark flag
    int benchmark_mode = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--benchmark") == 0) {
            benchmark_mode = 1;
            break;
        }
    }
    
    // Read all stdin
    char *input = NULL;
    size_t input_size = 0;
    size_t input_cap = 0;
    char buf[4096];
    while (fgets(buf, sizeof(buf), stdin)) {
        size_t len = strlen(buf);
        if (input_size + len >= input_cap) {
            input_cap = (input_size + len + 1) * 2;
            input = realloc(input, input_cap);
        }
        memcpy(input + input_size, buf, len);
        input_size += len;
    }
    if (input) input[input_size] = '\0';
    else { input = strdup("{}"); }
    
    // Handle benchmark mode
    if (benchmark_mode) {
        run_benchmarks(input);
        free(input);
        return 0;
    }
    
    printf("{\n");
    printf("  \"version\": \"1.0.0\",\n");
    printf("  \"description\": \"C roundtrip results\",\n");
    
    const char *categories[] = {"primitives", "strings", "bytes", "options", "vectors", "structs", "complex"};
    int num_cats = sizeof(categories) / sizeof(categories[0]);
    
    for (int ci = 0; ci < num_cats; ci++) {
        process_category(input, categories[ci], stdout, ci == num_cats - 1);
    }
    
    printf("}\n");
    
    free(input);
    return 0;
}
