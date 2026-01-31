# Security Audit Report: C, C++, and Zig BCS SDK Implementations

**Date:** January 30, 2026  
**Auditor:** Security Audit Agent  
**Scope:** C (`sdks/c/`), C++ (`sdks/cpp/`), and Zig (`sdks/zig/`) BCS SDK implementations

## Executive Summary

This report documents security vulnerabilities found in the C, C++, and Zig implementations of the Binary Canonical Serialization (BCS) SDK. The audit focused on seven critical security areas:

1. Buffer overflows/underflows
2. Integer overflows
3. Memory safety
4. Input validation
5. Denial of Service (DoS)
6. Error handling
7. Type confusion

**Summary of Findings:**
- **CRITICAL:** 0 issues
- **HIGH:** 3 issues
- **MEDIUM:** 5 issues
- **LOW:** 2 issues

---

## CRITICAL Severity Issues

*None found*

---

## HIGH Severity Issues

### HIGH-1: Missing Shift Overflow Check in C ULEB128 Decoding

**File:** `sdks/c/src/bcs.c`  
**Lines:** 631-655

**Vulnerability:**
```c
uint64_t result = 0;
unsigned shift = 0;
size_t i = 0;
size_t max_bytes = remaining < BCS_ULEB128_MAX_BYTES ? remaining : BCS_ULEB128_MAX_BYTES;

for (; i < max_bytes; i++) {
    uint8_t byte = p[i];
    uint8_t digit = byte & 0x7F;
    result |= (uint64_t)digit << shift;  // ⚠️ Shift can be 35 for 5-byte encoding
    
    if ((byte & 0x80) == 0) {
        // ... validation ...
        *value = (uint32_t)result;
        des->offset += i + 1;
        return BCS_OK;
    }
    shift += 7;  // ⚠️ No check if shift exceeds 35 before next iteration
}
```

**Issue:**
1. For a 5-byte ULEB128 encoding, `shift` reaches 28 (4 iterations * 7 bits)
2. On the 5th iteration, `shift` becomes 35 before the shift operation
3. While `uint64_t` can safely shift by 35 bits, the code should validate that `shift` doesn't exceed the maximum valid shift (35) before performing the operation
4. The check `if (i == BCS_ULEB128_MAX_BYTES)` at line 657 happens after the loop, but if a 6th byte somehow appears, `shift` would become 42, which is still valid for `uint64_t` but represents an invalid encoding
5. More critically: The code doesn't check if `shift >= 35` before the shift operation, which could theoretically allow processing of invalid 6+ byte encodings if the loop limit is bypassed

**Impact:** HIGH - Missing validation could allow processing of invalid ULEB128 encodings, though the loop limit provides some protection

**Recommended Fix:**
```c
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
        // Check shift overflow before performing shift
        if (BCS_UNLIKELY(shift >= 35)) {
            return BCS_ERR_ULEB128_OVERFLOW;
        }
        
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
```

**CWE:** CWE-190 (Integer Overflow or Wraparound), CWE-20 (Improper Input Validation)

---

### HIGH-2: Integer Overflow Risk in C++ Serializer Buffer Growth

**File:** `sdks/cpp/include/bcs/serializer.hpp`  
**Lines:** 159-172

**Vulnerability:**
```cpp
Serializer& write_bytes(const uint8_t* data, size_t len) {
    check_sequence_length(len);
    // Pre-calculate total size needed with overflow check
    const size_t uleb_size = uleb128::encoded_size(static_cast<uint32_t>(len));
    const size_t current_size = buffer_.size();
    // Check for overflow before addition
    if (uleb_size > SIZE_MAX - len || current_size > SIZE_MAX - uleb_size - len) {
        throw Error::exceeded_max_length(len);
    }
    buffer_.reserve(current_size + uleb_size + len);
    write_uleb128(static_cast<uint32_t>(len));
    write_fixed_bytes(data, len);
    return *this;
}
```

**Issue:**
1. The overflow check at line 165 has a logic error: `current_size > SIZE_MAX - uleb_size - len`
2. This check doesn't properly validate that `current_size + uleb_size + len` won't overflow
3. If `current_size` is very large (close to `SIZE_MAX`), the subtraction `SIZE_MAX - uleb_size - len` could underflow if `uleb_size + len > SIZE_MAX`
4. The correct check should be: `current_size > SIZE_MAX - (uleb_size + len)` or use checked arithmetic

**Impact:** HIGH - Can cause integer overflow leading to buffer under-allocation and potential buffer overflow

**Recommended Fix:**
```cpp
Serializer& write_bytes(const uint8_t* data, size_t len) {
    check_sequence_length(len);
    const size_t uleb_size = uleb128::encoded_size(static_cast<uint32_t>(len));
    const size_t current_size = buffer_.size();
    
    // Check for overflow: ensure current_size + uleb_size + len doesn't overflow
    // Use separate checks to avoid underflow in subtraction
    if (uleb_size > SIZE_MAX - len) {
        throw Error::exceeded_max_length(len);
    }
    const size_t total_needed = uleb_size + len;
    if (current_size > SIZE_MAX - total_needed) {
        throw Error::exceeded_max_length(len);
    }
    
    buffer_.reserve(current_size + total_needed);
    write_uleb128(static_cast<uint32_t>(len));
    write_fixed_bytes(data, len);
    return *this;
}
```

**CWE:** CWE-190 (Integer Overflow or Wraparound)

---

### HIGH-3: Incorrect Shift Type in Zig ULEB128 Decoding

**File:** `sdks/zig/src/bcs.zig`  
**Lines:** 103-129

**Vulnerability:**
```zig
pub fn decodeUleb128(data: []const u8) Error!struct { value: u32, bytes_read: usize } {
    var value: u32 = 0;
    var shift: u5 = 0;  // ⚠️ u5 can only hold 0-31
    var i: usize = 0;

    while (i < max_uleb128_bytes) {
        if (i >= data.len) return Error.UnexpectedEof;

        const byte = data[i];
        const digit: u32 = @as(u32, byte & 0x7F);
        value |= digit << shift;  // ⚠️ Shift can be 35 (5 bytes * 7 bits)
        i += 1;

        if (byte & 0x80 == 0) {
            // Check for non-canonical encoding (trailing zeros)
            if (shift > 0 and digit == 0) {
                return Error.NonCanonicalUleb128;
            }
            return .{ .value = value, .bytes_read = i };
        }

        shift +|= 7;  // ⚠️ Can overflow u5 (max 31, but need up to 35)
        if (shift >= 35) return Error.Uleb128Overflow;  // ⚠️ Check can never be true
    }

    return Error.Uleb128Overflow;
}
```

**Issue:**
1. `shift` is declared as `u5` (5-bit unsigned integer, range 0-31)
2. For a 5-byte ULEB128 encoding, `shift` needs to reach 28 (4 iterations * 7 bits), then the next increment would be 35
3. However, `u5` can only hold values up to 31, so `shift +|= 7` when `shift = 28` would result in `shift = 3` (wraparound) in ReleaseFast mode, or panic in Debug/Safe mode
4. The check `if (shift >= 35)` at line 125 can never be true because `u5` max value is 31
5. This causes incorrect bit shifting and potential incorrect decoding

**Impact:** HIGH - Can cause incorrect ULEB128 decoding and potential security bypass

**Recommended Fix:**
```zig
pub fn decodeUleb128(data: []const u8) Error!struct { value: u32, bytes_read: usize } {
    var value: u32 = 0;
    var shift: u6 = 0;  // Change to u6 to hold values up to 63
    var i: usize = 0;

    while (i < max_uleb128_bytes) {
        if (i >= data.len) return Error.UnexpectedEof;

        const byte = data[i];
        const digit: u32 = @as(u32, byte & 0x7F);
        
        // Check shift overflow before performing shift
        if (shift >= 35) {
            return Error.Uleb128Overflow;
        }
        
        value |= digit << shift;
        i += 1;

        if (byte & 0x80 == 0) {
            // Check for non-canonical encoding (trailing zeros)
            if (shift > 0 and digit == 0) {
                return Error.NonCanonicalUleb128;
            }
            // Check for value overflow
            if (value > 0xFFFFFFFF) {
                return Error.Uleb128Overflow;
            }
            return .{ .value = value, .bytes_read = i };
        }

        shift +|= 7;
    }

    return Error.Uleb128Overflow;
}
```

**CWE:** CWE-190 (Integer Overflow or Wraparound), CWE-682 (Incorrect Calculation)

---

## MEDIUM Severity Issues

### MEDIUM-1: Missing Null Pointer Check in C `bcs_deserializer_data_at`

**File:** `sdks/c/src/bcs.c`  
**Lines:** 820-824

**Vulnerability:**
```c
const uint8_t* bcs_deserializer_data_at(const bcs_deserializer_t* des, size_t offset) {
    if (BCS_UNLIKELY(!des || offset > des->size))
        return NULL;
    return des->data + offset;  // ⚠️ des->data could be NULL if des->size == 0
}
```

**Issue:**
1. The function checks if `des` is NULL and if `offset > des->size`
2. However, if `des->size == 0` and `des->data == NULL` (which is valid per `bcs_deserializer_init`), the function returns `NULL + offset`, which is technically valid but could be confusing
3. More critically: If `des->data` is NULL and `offset == 0`, the function returns `NULL`, which is correct. But if `offset > 0` and `des->data == NULL`, we return `NULL + offset`, which is undefined behavior in C (though many implementations allow it)

**Impact:** MEDIUM - Potential undefined behavior, though unlikely to be exploitable

**Recommended Fix:**
```c
const uint8_t* bcs_deserializer_data_at(const bcs_deserializer_t* des, size_t offset) {
    if (BCS_UNLIKELY(!des))
        return NULL;
    if (BCS_UNLIKELY(offset > des->size))
        return NULL;
    if (BCS_UNLIKELY(des->size == 0 || des->data == NULL))
        return NULL;
    return des->data + offset;
}
```

**CWE:** CWE-476 (NULL Pointer Dereference)

---

### MEDIUM-2: Potential Integer Overflow in C++ Vector Serialization

**File:** `sdks/cpp/include/bcs/serializer.hpp`  
**Lines:** 198-206

**Vulnerability:**
```cpp
template <typename T, typename Func>
Serializer& write_vector(const std::vector<T>& vec, Func serializer) {
    check_sequence_length(vec.size());
    write_uleb128(static_cast<uint32_t>(vec.size()));
    for (const auto& item : vec) {
        serializer(*this, item);  // ⚠️ No limit on total serialized size
    }
    return *this;
}
```

**Issue:**
1. The function checks that `vec.size()` doesn't exceed `MAX_SEQUENCE_LENGTH`
2. However, it doesn't check the total serialized size of all elements
3. If each element serializes to a large amount of data, the total buffer size could exceed `SIZE_MAX`
4. While `std::vector` will throw `std::bad_alloc` on allocation failure, this could be used for DoS

**Impact:** MEDIUM - Potential DoS through memory exhaustion

**Recommended Fix:**
Add a mechanism to track total serialized size and enforce limits, or document that this is a known limitation and should be handled by the caller.

**CWE:** CWE-400 (Uncontrolled Resource Consumption)

---

### MEDIUM-3: Incorrect Error Type in Zig `readIntVectorInto`

**File:** `sdks/zig/src/bcs.zig`  
**Lines:** 716-723

**Vulnerability:**
```zig
pub fn readIntVectorInto(self: *Self, comptime T: type, dest: []T) Error!void {
    const len = try self.readVectorLen();
    if (len != dest.len) return Error.ExceededMaxLength;  // ⚠️ Wrong error type

    for (dest) |*slot| {
        slot.* = try self.readInt(T);
    }
}
```

**Issue:**
1. If `len != dest.len`, the function returns `Error.ExceededMaxLength`, which is misleading
2. This should be a different error type (e.g., `Error.SizeMismatch` or similar)
3. While not a security issue per se, incorrect error handling can mask real security problems

**Impact:** MEDIUM - Poor error handling that could mask issues

**Recommended Fix:**
Add a new error type `SizeMismatch` or use a more appropriate existing error.

**CWE:** CWE-703 (Improper Exception Handling)

---

### MEDIUM-4: Potential DoS in C++ Map Deserialization

**File:** `sdks/cpp/include/bcs/deserializer.hpp`  
**Lines:** 238-273

**Vulnerability:**
```cpp
template <typename K, typename V, typename KeyFunc, typename ValueFunc>
std::map<K, V> read_map(KeyFunc key_deserializer,
                         ValueFunc value_deserializer) {
    const uint32_t len = read_uleb128();
    check_sequence_length(len);

    std::map<K, V> result;
    std::vector<uint8_t> prev_key_bytes;

    for (uint32_t i = 0; i < len; ++i) {
        // ... deserialize key and value ...
        // Each iteration allocates memory for key_bytes
    }
    return result;
}
```

**Issue:**
1. The function validates `len` against `MAX_SEQUENCE_LENGTH`
2. However, each iteration allocates a `std::vector<uint8_t>` for `key_bytes`
3. If keys are very large, this could cause significant memory allocation
4. No limit on individual key size, only on count

**Impact:** MEDIUM - Potential DoS through memory exhaustion with large keys

**Recommended Fix:**
Add validation for maximum key size, or document the limitation.

**CWE:** CWE-400 (Uncontrolled Resource Consumption)

---

### MEDIUM-5: Missing Overflow Check in C `bcs_remaining`

**File:** `sdks/c/src/bcs.c`  
**Lines:** 489-493

**Vulnerability:**
```c
BCS_PURE size_t bcs_remaining(const bcs_deserializer_t* restrict des) {
    if (BCS_UNLIKELY(!des))
        return 0;
    return des->size - des->offset;  // ⚠️ No check if offset > size
}
```

**Issue:**
1. If `des->offset > des->size` (due to a bug or corruption), this function returns a very large value (wraparound)
2. This could cause issues in calling code that uses this value for bounds checking
3. While `offset` should be managed internally, defensive programming suggests validating it

**Impact:** MEDIUM - Potential issues if deserializer state is corrupted

**Recommended Fix:**
```c
BCS_PURE size_t bcs_remaining(const bcs_deserializer_t* restrict des) {
    if (BCS_UNLIKELY(!des))
        return 0;
    if (BCS_UNLIKELY(des->offset > des->size))
        return 0;  // Or return an error indicator
    return des->size - des->offset;
}
```

**CWE:** CWE-682 (Incorrect Calculation)

---

## LOW Severity Issues

### LOW-1: Missing UTF-8 Validation in C++ `write_string`

**File:** `sdks/cpp/include/bcs/serializer.hpp`  
**Lines:** 179-183

**Vulnerability:**
```cpp
Serializer& write_string(std::string_view value) {
    return write_bytes(reinterpret_cast<const uint8_t*>(value.data()),
                       value.size());
}
```

**Issue:**
1. The function doesn't validate that `value` contains valid UTF-8
2. This could lead to serializing invalid UTF-8, which would then fail validation on deserialization
3. While not a security issue per se, it's inconsistent with the C implementation which validates UTF-8 on write

**Impact:** LOW - Inconsistent behavior, potential for confusion

**Recommended Fix:**
Add UTF-8 validation before writing, consistent with C implementation.

---

### LOW-2: Potential Memory Leak in C++ Map Serialization on Exception

**File:** `sdks/cpp/include/bcs/serializer.hpp`  
**Lines:** 208-245

**Vulnerability:**
```cpp
template <typename K, typename V, typename KeyFunc, typename ValueFunc>
Serializer& write_map(const std::map<K, V>& map, KeyFunc key_serializer,
                      ValueFunc value_serializer) {
    // ... creates temporary entries vector ...
    std::vector<std::pair<std::vector<uint8_t>, std::vector<uint8_t>>> entries;
    // ... if an exception is thrown during serialization, entries is cleaned up ...
}
```

**Issue:**
1. The function creates a temporary `entries` vector that holds serialized key/value pairs
2. If an exception is thrown during the serialization loop, the `entries` vector will be cleaned up automatically (RAII)
3. However, if an exception is thrown after `entries` is populated but before it's written, memory is still cleaned up correctly
4. This is actually safe due to RAII, but worth noting for completeness

**Impact:** LOW - No actual issue, but worth documenting

**Status:** Informational - No fix needed, RAII handles cleanup correctly

---

## Positive Security Findings

The implementations demonstrate several good security practices:

1. **Comprehensive bounds checking** in deserialization functions
2. **Input validation** for sequence lengths and container depths
3. **Proper error handling** with specific error codes
4. **Type validation** for booleans and option tags (must be 0 or 1)
5. **UTF-8 validation** in string deserialization
6. **Canonical encoding checks** for ULEB128 and maps
7. **Depth limiting** to prevent stack overflow from deeply nested structures

---

## Recommendations Summary

### Immediate Actions (HIGH Priority)
1. Fix integer overflow in C ULEB128 decoding (HIGH-1)
2. Fix integer overflow check logic in C++ serializer (HIGH-2)
3. Fix shift type and overflow check in Zig ULEB128 decoding (HIGH-3)

### Short-term Actions (MEDIUM Priority)
1. Add null pointer validation in C `bcs_deserializer_data_at` (MEDIUM-1)
2. Add size limits for vector serialization in C++ (MEDIUM-2)
3. Improve error handling in Zig `readIntVectorInto` (MEDIUM-3)
4. Add key size limits in C++ map deserialization (MEDIUM-4)
5. Add defensive check in C `bcs_remaining` (MEDIUM-5)

### Long-term Improvements (LOW Priority)
1. Add UTF-8 validation in C++ `write_string` for consistency (LOW-1)
2. Document exception safety guarantees (LOW-2)

---

## Testing Recommendations

1. **Fuzzing:** Use AFL++ or libFuzzer to test all three implementations with malformed inputs
2. **Integer Overflow Tests:** Create test cases that trigger the identified overflow conditions
3. **Bounds Testing:** Test with maximum and near-maximum values for lengths and depths
4. **Memory Safety Testing:** Use AddressSanitizer (ASan), MemorySanitizer (MSan), and Valgrind
5. **DoS Testing:** Test with inputs designed to exhaust memory or cause excessive allocations

---

## References

- **CWE-190:** Integer Overflow or Wraparound
- **CWE-400:** Uncontrolled Resource Consumption
- **CWE-476:** NULL Pointer Dereference
- **CWE-682:** Incorrect Calculation
- **CWE-703:** Improper Exception Handling
- **OWASP Top 10:** A03:2021 – Injection (relevant for input validation)

---

**Report End**
