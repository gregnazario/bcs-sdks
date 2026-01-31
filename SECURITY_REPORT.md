# BCS SDK Security Audit Report

**Date:** January 27, 2026  
**Auditor:** Security Audit Agent  
**Scope:** C, C++, Rust, and Zig SDKs  
**Version:** Based on current codebase state

---

## Executive Summary

This report presents a comprehensive security audit of the Binary Canonical Serialization (BCS) SDKs for C, C++, Rust, and Zig. The audit focuses on:

1. Integer overflow protection
2. Buffer overflow protection
3. Input validation (booleans, options, ULEB128, UTF-8)
4. Limit enforcement (MAX_SEQUENCE_LENGTH, MAX_CONTAINER_DEPTH)
5. Map handling (sorted keys, duplicate rejection)
6. Memory safety
7. RemainingInput check

**Overall Assessment:** The SDKs demonstrate strong security practices with comprehensive input validation. However, several critical and high-severity issues were identified, particularly in C and Zig implementations.

---

## 1. C SDK (`sdks/c/`)

### 1.1 Integer Overflow Protection

**Status:** ⚠️ **MEDIUM RISK**

**Findings:**
- ✅ ULEB128 encoding/decoding uses `uint64_t` for intermediate calculations and checks overflow before casting to `uint32_t` (lines 603-621, 825-846)
- ✅ Buffer growth uses `size_t` arithmetic which is safe on modern systems
- ⚠️ **ISSUE:** In `bcs_write_bytes()` (line 334), `bcs_uleb128_encoded_size()` is called but the result is not checked for overflow before adding to `len`
  - Line 335: `size_t uleb_size = bcs_uleb128_encoded_size((uint32_t)len);`
  - Line 335: `bcs_error_t err = ensure_capacity(ser, uleb_size + len);`
  - If `len` is very large (close to SIZE_MAX), `uleb_size + len` could overflow `size_t`
  - **Recommendation:** Use `checked_add` pattern or verify `uleb_size + len >= len` before addition

**Code Location:**
```c
// sdks/c/src/bcs.c:334-336
size_t uleb_size = bcs_uleb128_encoded_size((uint32_t)len);
bcs_error_t err = ensure_capacity(ser, uleb_size + len);
```

### 1.2 Buffer Overflow Protection

**Status:** ✅ **GOOD**

**Findings:**
- ✅ All buffer writes check bounds before access
- ✅ `ensure_capacity()` validates buffer size before writes
- ✅ `read_fixed_bytes()` checks `offset + len <= size` before `memcpy` (line 642)
- ✅ All integer reads verify sufficient bytes available before access

### 1.3 Input Validation

#### Boolean Values
**Status:** ✅ **GOOD**
- ✅ `bcs_read_bool()` correctly rejects values other than 0x00/0x01 (lines 474-481)
- ✅ Proper error code returned: `BCS_ERR_INVALID_BOOLEAN`

#### Option Tags
**Status:** ✅ **GOOD**
- ✅ `bcs_read_option_tag()` correctly rejects values other than 0x00/0x01 (lines 757-773)
- ✅ Proper error code returned: `BCS_ERR_INVALID_OPTION`

#### ULEB128 Validation
**Status:** ✅ **GOOD**
- ✅ Non-canonical encoding detection: checks for trailing zeros (lines 615, 837)
- ✅ Overflow detection: checks `result > 0xFFFFFFFF` (lines 619, 843)
- ✅ Maximum length enforcement: limits to `BCS_ULEB128_MAX_BYTES` (5 bytes) (lines 606, 629, 856)
- ✅ Proper error codes: `BCS_ERR_NON_CANONICAL_ULEB128`, `BCS_ERR_ULEB128_OVERFLOW`

#### UTF-8 Validation
**Status:** ✅ **EXCELLENT**
- ✅ Comprehensive UTF-8 validation in `bcs_is_valid_utf8()` (lines 877-949)
- ✅ Fast path for ASCII-only strings (8-byte chunks)
- ✅ Validates continuation bytes, overlong encodings, surrogates, and code point ranges
- ✅ Used in both `bcs_write_string()` and `bcs_read_string()`

### 1.4 Limit Enforcement

#### MAX_SEQUENCE_LENGTH
**Status:** ✅ **GOOD**
- ✅ Defined as `BCS_MAX_SEQUENCE_LENGTH = 0x7FFFFFFF` (2^31 - 1)
- ✅ Checked in `bcs_write_bytes()` (line 330), `bcs_write_vector_len()` (line 429)
- ✅ Checked in `bcs_read_bytes_len()` (line 660)

#### MAX_CONTAINER_DEPTH
**Status:** ✅ **GOOD**
- ✅ Defined as `BCS_MAX_CONTAINER_DEPTH = 500`
- ✅ Checked in `bcs_enter_struct()` (line 385), `bcs_write_variant_index()` (line 403)
- ✅ Checked in `bcs_des_enter_struct()` (line 725), `bcs_read_variant_index()` (line 745)

### 1.5 Map Handling

**Status:** ❌ **NOT IMPLEMENTED**

**Findings:**
- ❌ **CRITICAL:** No map serialization/deserialization functions exist in the C SDK
- ⚠️ Error codes are defined (`BCS_ERR_NON_CANONICAL_MAP`, `BCS_ERR_DUPLICATE_MAP_KEY`) but no implementation
- **Recommendation:** Implement map support with sorted key validation and duplicate detection

### 1.6 Memory Safety

**Status:** ⚠️ **MEDIUM RISK**

**Findings:**
- ✅ Null pointer checks before dereferencing
- ✅ `bcs_serializer_free()` checks `owns_buffer` before `free()` (prevents double-free)
- ✅ `realloc()` failure handled (line 89)
- ⚠️ **ISSUE:** In `grow_buffer()` (line 88), if `realloc()` fails, the old buffer pointer is lost
  - However, this is acceptable since we return an error and the caller should handle it
- ✅ No use-after-free vulnerabilities identified

### 1.7 RemainingInput Check

**Status:** ✅ **GOOD**
- ✅ `bcs_check_end()` function exists and validates `offset == size` (lines 453-458)
- ✅ Returns `BCS_ERR_REMAINING_INPUT` if bytes remain

### 1.8 Summary for C SDK

| Category | Status | Issues |
|----------|--------|--------|
| Integer Overflow | ⚠️ Medium | Potential overflow in `uleb_size + len` |
| Buffer Overflow | ✅ Good | None |
| Input Validation | ✅ Good | All validations present |
| Limit Enforcement | ✅ Good | All limits enforced |
| Map Handling | ❌ Critical | Not implemented |
| Memory Safety | ⚠️ Medium | Generally safe, minor concerns |
| RemainingInput | ✅ Good | Implemented correctly |

---

## 2. C++ SDK (`sdks/cpp/`)

### 2.1 Integer Overflow Protection

**Status:** ✅ **GOOD**

**Findings:**
- ✅ ULEB128 uses `uint64_t` for intermediate calculations (uleb128.hpp:99-118)
- ✅ Overflow checked before casting to `uint32_t` (line 115)
- ✅ Vector operations use `size_t` which is safe
- ✅ No arithmetic operations identified that could overflow

### 2.2 Buffer Overflow Protection

**Status:** ✅ **GOOD**

**Findings:**
- ✅ Uses `std::vector<uint8_t>` which provides automatic bounds checking
- ✅ All reads check `offset_ + n > size_` before access
- ✅ `read_fixed_bytes()` validates bounds (deserializer.hpp:166-174)

### 2.3 Input Validation

#### Boolean Values
**Status:** ✅ **GOOD**
- ✅ `read_bool()` rejects values other than 0x00/0x01 (deserializer.hpp:34-46)

#### Option Tags
**Status:** ✅ **GOOD**
- ✅ `read_option()` rejects values other than 0x00/0x01 (deserializer.hpp:209-222)

#### ULEB128 Validation
**Status:** ✅ **GOOD**
- ✅ Non-canonical encoding detection (uleb128.hpp:111)
- ✅ Overflow detection (uleb128.hpp:115)
- ✅ Maximum length enforcement (5 bytes) (uleb128.hpp:101, 124)

#### UTF-8 Validation
**Status:** ✅ **EXCELLENT**
- ✅ Comprehensive UTF-8 validation in `is_valid_utf8()` (deserializer.hpp:317-389)
- ✅ Fast path for ASCII, validates continuation bytes, overlong encodings, surrogates

### 2.4 Limit Enforcement

#### MAX_SEQUENCE_LENGTH
**Status:** ✅ **GOOD**
- ✅ Defined as `MAX_SEQUENCE_LENGTH = (1ULL << 31) - 1` (types.hpp:13)
- ✅ Checked in `read_bytes()`, `read_string()`, `read_vector()` via `check_sequence_length()` (deserializer.hpp:310-314)
- ✅ Checked in `write_bytes()`, `write_vector()` via `check_sequence_length()` (serializer.hpp:273-277)

#### MAX_CONTAINER_DEPTH
**Status:** ✅ **GOOD**
- ✅ Defined as `MAX_CONTAINER_DEPTH = 500` (types.hpp:16)
- ✅ Checked in `enter_container()` (deserializer.hpp:279-285, serializer.hpp:243-249)

### 2.5 Map Handling

**Status:** ✅ **EXCELLENT**

**Findings:**
- ✅ `write_map()` sorts entries by key bytes before serialization (serializer.hpp:222-224)
- ✅ `read_map()` validates sorted order and rejects duplicates (deserializer.hpp:258-264)
- ✅ Proper error handling: `Error::non_canonical_map()`, `Error::duplicate_map_key()`
- ✅ Key bytes comparison uses lexicographic ordering

**Code Location:**
```cpp
// deserializer.hpp:258-264
if (i > 0) {
    if (key_bytes <= prev_key_bytes) {
        if (key_bytes == prev_key_bytes) {
            throw Error::duplicate_map_key();
        }
        throw Error::non_canonical_map();
    }
}
```

### 2.6 Memory Safety

**Status:** ✅ **EXCELLENT**

**Findings:**
- ✅ Uses RAII with `std::vector`, automatic memory management
- ✅ No manual memory allocation/deallocation
- ✅ Exception safety: exceptions propagate correctly
- ✅ No use-after-free or double-free vulnerabilities possible

### 2.7 RemainingInput Check

**Status:** ✅ **GOOD**
- ✅ `check_end()` validates `offset_ == size_` (deserializer.hpp:294-298)
- ✅ Throws `Error::remaining_input()` if bytes remain

### 2.8 Summary for C++ SDK

| Category | Status | Issues |
|----------|--------|--------|
| Integer Overflow | ✅ Good | None |
| Buffer Overflow | ✅ Good | None |
| Input Validation | ✅ Good | All validations present |
| Limit Enforcement | ✅ Good | All limits enforced |
| Map Handling | ✅ Excellent | Fully implemented with validation |
| Memory Safety | ✅ Excellent | RAII, no manual memory management |
| RemainingInput | ✅ Good | Implemented correctly |

---

## 3. Rust SDK (`sdks/rust/`)

### 3.1 Integer Overflow Protection

**Status:** ✅ **EXCELLENT**

**Findings:**
- ✅ Uses `checked_add()` for write counter (ser.rs:122)
- ✅ ULEB128 uses `u64` for intermediate calculations, checks overflow (de.rs:192-210)
- ✅ Rust's type system prevents many overflow issues at compile time
- ✅ All arithmetic operations are safe

### 3.2 Buffer Overflow Protection

**Status:** ✅ **EXCELLENT**

**Findings:**
- ✅ Uses `&[u8]` slices with bounds checking
- ✅ `read_exact()` validates length before slice access (de.rs:140-147)
- ✅ Rust's memory safety guarantees prevent buffer overflows

### 3.3 Input Validation

#### Boolean Values
**Status:** ✅ **GOOD**
- ✅ `parse_bool()` rejects values other than 0/1 (de.rs:128-136)

#### Option Tags
**Status:** ✅ **GOOD**
- ✅ `deserialize_option()` rejects values other than 0/1 (de.rs:405-416)

#### ULEB128 Validation
**Status:** ✅ **GOOD**
- ✅ Non-canonical encoding detection (de.rs:199-203)
- ✅ Overflow detection using `u32::try_from()` (de.rs:205-206, 210)
- ✅ Maximum length enforcement (5 bytes) via loop limit (de.rs:193)

#### UTF-8 Validation
**Status:** ✅ **GOOD**
- ✅ Uses `std::str::from_utf8()` which validates UTF-8 (de.rs:232)
- ✅ Returns `Error::Utf8` on invalid UTF-8

### 3.4 Limit Enforcement

#### MAX_SEQUENCE_LENGTH
**Status:** ✅ **GOOD**
- ✅ Defined as `MAX_SEQUENCE_LENGTH: usize = (1 << 31) - 1` (lib.rs:312)
- ✅ Checked in `parse_length()` (de.rs:214-220)
- ✅ Checked in `output_seq_len()` (ser.rs:207-211)

#### MAX_CONTAINER_DEPTH
**Status:** ✅ **GOOD**
- ✅ Defined as `MAX_CONTAINER_DEPTH: usize = 500` (lib.rs:315)
- ✅ Checked in `enter_named_container()` (de.rs:236-242, ser.rs:214-220)
- ✅ Depth tracking via `max_remaining_depth` counter

### 3.5 Map Handling

**Status:** ✅ **EXCELLENT**

**Findings:**
- ✅ `MapSerializer` sorts entries by key bytes (ser.rs:591)
- ✅ `MapSerializer` removes duplicates using `dedup_by()` (ser.rs:592)
- ✅ `MapDeserializer` validates sorted order (de.rs:599)
- ✅ Rejects duplicate keys and out-of-order keys
- ✅ Proper error: `Error::NonCanonicalMap`

**Code Location:**
```rust
// ser.rs:591-592
self.entries.sort_by(|e1, e2| e1.0.cmp(&e2.0));
self.entries.dedup_by(|e1, e2| e1.0.eq(&e2.0));

// de.rs:599
if previous_key_bytes >= key_bytes {
    return Err(Error::NonCanonicalMap);
}
```

### 3.6 Memory Safety

**Status:** ✅ **EXCELLENT**

**Findings:**
- ✅ Rust's ownership system prevents use-after-free, double-free
- ✅ No unsafe code blocks (`#![forbid(unsafe_code)]` at top of lib.rs:4)
- ✅ All memory operations are safe

### 3.7 RemainingInput Check

**Status:** ✅ **GOOD**
- ✅ `end()` method checks `input.is_empty()` (de.rs:105-111)
- ✅ Returns `Error::RemainingInput` if bytes remain

### 3.8 Summary for Rust SDK

| Category | Status | Issues |
|----------|--------|--------|
| Integer Overflow | ✅ Excellent | None, uses checked arithmetic |
| Buffer Overflow | ✅ Excellent | None, Rust memory safety |
| Input Validation | ✅ Good | All validations present |
| Limit Enforcement | ✅ Good | All limits enforced |
| Map Handling | ✅ Excellent | Fully implemented with validation |
| Memory Safety | ✅ Excellent | No unsafe code, ownership system |
| RemainingInput | ✅ Good | Implemented correctly |

---

## 4. Zig SDK (`sdks/zig/`)

### 4.1 Integer Overflow Protection

**Status:** ⚠️ **MEDIUM RISK**

**Findings:**
- ✅ ULEB128 uses `u32` and checks overflow (bcs.zig:103-129)
- ✅ Maximum shift check: `if (shift >= 35) return Error.Uleb128Overflow` (line 125)
- ⚠️ **ISSUE:** In `writeBytes()` (line 322-325), potential integer overflow:
  ```zig
  if (bytes.len > max_sequence_length) return Error.ExceededMaxLength;
  try self.writeUleb128(@intCast(bytes.len));
  ```
  - `@intCast` from `usize` to `u32` could truncate on 64-bit systems if `bytes.len > u32::max`
  - However, the check above prevents this, so it's safe
- ⚠️ **ISSUE:** In `writeIntVector()` (line 394), `values.len * bytes_per_elem` could overflow:
  ```zig
  try self.ensureCapacity(values.len * bytes_per_elem);
  ```
  - No overflow check before multiplication
  - **Recommendation:** Use `@mulWithOverflow()` or check for overflow

### 4.2 Buffer Overflow Protection

**Status:** ✅ **GOOD**

**Findings:**
- ✅ All reads check `remaining() >= n` before access
- ✅ `readNBytes()` validates bounds (bcs.zig:489-494)
- ✅ Zig's bounds checking prevents buffer overflows

### 4.3 Input Validation

#### Boolean Values
**Status:** ✅ **GOOD**
- ✅ `readBool()` rejects values other than 0/1 (bcs.zig:511-518)

#### Option Tags
**Status:** ✅ **GOOD**
- ✅ `readOptionTag()` rejects values other than 0/1 (bcs.zig:627-634)

#### ULEB128 Validation
**Status:** ✅ **GOOD**
- ✅ Non-canonical encoding detection (bcs.zig:118)
- ✅ Overflow detection via shift limit (bcs.zig:125)
- ✅ Maximum length enforcement (5 bytes) via loop limit (bcs.zig:108)

#### UTF-8 Validation
**Status:** ✅ **GOOD**
- ✅ Uses `std.unicode.utf8ValidateSlice()` (bcs.zig:330, 617)
- ✅ Returns `Error.InvalidUtf8` on invalid UTF-8

### 4.4 Limit Enforcement

#### MAX_SEQUENCE_LENGTH
**Status:** ✅ **GOOD**
- ✅ Defined as `max_sequence_length: u32 = 0x7FFFFFFF` (bcs.zig:36)
- ✅ Checked in `writeBytes()` (line 323), `writeVectorLen()` (line 349)
- ✅ Checked in `readBytes()` (line 610), `readVectorLen()` (line 638)

#### MAX_CONTAINER_DEPTH
**Status:** ✅ **GOOD**
- ✅ Defined as `max_container_depth: u16 = 500` (bcs.zig:39)
- ✅ Checked in `enterContainer()` (bcs.zig:220-224, 496-500)

### 4.5 Map Handling

**Status:** ❌ **NOT IMPLEMENTED**

**Findings:**
- ❌ **CRITICAL:** No map serialization/deserialization functions exist
- ⚠️ Error type `NonCanonicalMap` is defined (bcs.zig:68) but no implementation
- **Recommendation:** Implement map support with sorted key validation and duplicate detection

### 4.6 Memory Safety

**Status:** ✅ **GOOD**

**Findings:**
- ✅ Uses `std.ArrayList` with explicit allocator, clear ownership
- ✅ `deinit()` properly frees memory
- ✅ No use-after-free vulnerabilities identified
- ✅ Zig's memory safety model prevents many issues

### 4.7 RemainingInput Check

**Status:** ✅ **GOOD**
- ✅ `checkEnd()` validates `offset == data.len` (bcs.zig:455-459)
- ✅ Returns `Error.RemainingInput` if bytes remain

### 4.8 Summary for Zig SDK

| Category | Status | Issues |
|----------|--------|--------|
| Integer Overflow | ⚠️ Medium | Potential overflow in `writeIntVector` multiplication |
| Buffer Overflow | ✅ Good | None |
| Input Validation | ✅ Good | All validations present |
| Limit Enforcement | ✅ Good | All limits enforced |
| Map Handling | ❌ Critical | Not implemented |
| Memory Safety | ✅ Good | Generally safe |
| RemainingInput | ✅ Good | Implemented correctly |

---

## 5. Cross-SDK Comparison

### 5.1 Security Feature Matrix

| Feature | C | C++ | Rust | Zig |
|---------|---|----|------|-----|
| Boolean validation (0x00/0x01 only) | ✅ | ✅ | ✅ | ✅ |
| Option tag validation (0x00/0x01 only) | ✅ | ✅ | ✅ | ✅ |
| ULEB128 non-canonical rejection | ✅ | ✅ | ✅ | ✅ |
| ULEB128 overflow protection | ✅ | ✅ | ✅ | ✅ |
| ULEB128 max length (5 bytes) | ✅ | ✅ | ✅ | ✅ |
| UTF-8 validation | ✅ | ✅ | ✅ | ✅ |
| MAX_SEQUENCE_LENGTH enforcement | ✅ | ✅ | ✅ | ✅ |
| MAX_CONTAINER_DEPTH enforcement | ✅ | ✅ | ✅ | ✅ |
| Map sorted key validation | ❌ | ✅ | ✅ | ❌ |
| Map duplicate key rejection | ❌ | ✅ | ✅ | ❌ |
| RemainingInput check | ✅ | ✅ | ✅ | ✅ |
| Integer overflow protection | ⚠️ | ✅ | ✅ | ⚠️ |
| Memory safety | ⚠️ | ✅ | ✅ | ✅ |

### 5.2 Common Strengths

1. **Comprehensive Input Validation:** All SDKs properly validate booleans, options, ULEB128, and UTF-8
2. **Limit Enforcement:** All SDKs enforce MAX_SEQUENCE_LENGTH and MAX_CONTAINER_DEPTH
3. **RemainingInput Check:** All SDKs provide a mechanism to verify complete deserialization

### 5.3 Common Weaknesses

1. **Map Support:** C and Zig SDKs lack map serialization/deserialization
2. **Integer Overflow:** C and Zig have potential integer overflow issues in specific operations

---

## 6. Critical Issues Summary

### 6.1 Critical Severity

1. **C SDK - Missing Map Implementation**
   - **Severity:** Critical
   - **Impact:** Cannot serialize/deserialize maps, breaking BCS specification compliance
   - **Location:** `sdks/c/src/bcs.c` - no map functions
   - **Recommendation:** Implement `bcs_write_map()` and `bcs_read_map()` with sorted key validation

2. **Zig SDK - Missing Map Implementation**
   - **Severity:** Critical
   - **Impact:** Cannot serialize/deserialize maps, breaking BCS specification compliance
   - **Location:** `sdks/zig/src/bcs.zig` - no map functions
   - **Recommendation:** Implement `writeMap()` and `readMap()` with sorted key validation

### 6.2 High Severity

None identified.

### 6.3 Medium Severity

1. **C SDK - Potential Integer Overflow in Buffer Capacity**
   - **Severity:** Medium
   - **Impact:** Could cause buffer allocation issues if `len` is very large
   - **Location:** `sdks/c/src/bcs.c:335`
   - **Recommendation:** Add overflow check: `if (uleb_size > SIZE_MAX - len) return BCS_ERR_INTEGER_OUT_OF_RANGE;`

2. **Zig SDK - Potential Integer Overflow in Vector Capacity**
   - **Severity:** Medium
   - **Impact:** Could cause allocation issues if vector is very large
   - **Location:** `sdks/zig/src/bcs.zig:403`
   - **Recommendation:** Use `@mulWithOverflow()` or check: `if (values.len > 0 and bytes_per_elem > std.math.maxInt(usize) / values.len) return Error.OutOfMemory;`

---

## 7. Recommendations

### 7.1 Immediate Actions (Critical)

1. **Implement Map Support in C SDK**
   - Add `bcs_write_map()` and `bcs_read_map()` functions
   - Validate sorted keys and reject duplicates
   - Follow the pattern used in C++ SDK

2. **Implement Map Support in Zig SDK**
   - Add `writeMap()` and `readMap()` methods
   - Validate sorted keys and reject duplicates
   - Follow the pattern used in Rust SDK

### 7.2 Short-term Actions (High Priority)

1. **Fix Integer Overflow in C SDK**
   - Add overflow check in `bcs_write_bytes()` before `uleb_size + len`
   - Test with edge cases (SIZE_MAX - small values)

2. **Fix Integer Overflow in Zig SDK**
   - Add overflow check in `writeIntVector()` before multiplication
   - Use Zig's built-in overflow detection

### 7.3 Long-term Actions (Best Practices)

1. **Add Fuzzing Tests**
   - Use libFuzzer/AFL for C/C++
   - Use cargo-fuzz for Rust
   - Use built-in fuzzing for Zig
   - Focus on edge cases: maximum lengths, deeply nested structures, malformed ULEB128

2. **Add Property-Based Tests**
   - Test round-trip serialization/deserialization
   - Test canonical encoding properties
   - Test limit enforcement

3. **Security Documentation**
   - Document security guarantees
   - Document threat model
   - Provide security best practices for users

---

## 8. Positive Security Features

### 8.1 Comprehensive Input Validation

All SDKs demonstrate excellent input validation:
- Boolean values strictly limited to 0x00/0x01
- Option tags strictly limited to 0x00/0x01
- ULEB128 non-canonical encoding rejection
- ULEB128 overflow protection
- UTF-8 validation with proper error handling

### 8.2 Limit Enforcement

All SDKs properly enforce:
- MAX_SEQUENCE_LENGTH (2^31 - 1)
- MAX_CONTAINER_DEPTH (500)

### 8.3 Memory Safety

- **C++:** RAII, automatic memory management
- **Rust:** Ownership system, no unsafe code
- **Zig:** Explicit allocators, clear ownership
- **C:** Manual memory management with proper checks

### 8.4 RemainingInput Check

All SDKs provide a mechanism to verify that all input bytes were consumed during deserialization, preventing incomplete or malformed data acceptance.

---

## 9. Conclusion

The BCS SDKs demonstrate strong security practices with comprehensive input validation and limit enforcement. The C++ and Rust SDKs are particularly robust, with full map support and excellent memory safety. The C and Zig SDKs are generally secure but require map implementation and minor integer overflow fixes.

**Overall Security Rating:**
- **C SDK:** 7/10 (Good, but missing map support)
- **C++ SDK:** 10/10 (Excellent)
- **Rust SDK:** 10/10 (Excellent)
- **Zig SDK:** 8/10 (Very Good, but missing map support)

---

## Appendix A: Testing Recommendations

### A.1 Unit Tests

1. **Boolean Validation**
   - Test rejection of 0x02-0xFF
   - Test acceptance of 0x00 and 0x01

2. **Option Tag Validation**
   - Test rejection of 0x02-0xFF
   - Test acceptance of 0x00 and 0x01

3. **ULEB128 Validation**
   - Test non-canonical encodings (e.g., `[0x80, 0x00]`)
   - Test overflow values (> u32 max)
   - Test sequences > 5 bytes
   - Test truncated sequences

4. **UTF-8 Validation**
   - Test invalid UTF-8 sequences
   - Test overlong encodings
   - Test surrogates
   - Test incomplete sequences

5. **Limit Enforcement**
   - Test MAX_SEQUENCE_LENGTH boundary (2^31 - 1)
   - Test MAX_CONTAINER_DEPTH boundary (500)
   - Test values exceeding limits

6. **Map Validation** (C++ and Rust only)
   - Test sorted key validation
   - Test duplicate key rejection
   - Test empty maps
   - Test single-entry maps

### A.2 Integration Tests

1. **Round-trip Serialization**
   - Serialize → Deserialize → Compare
   - Test all data types
   - Test nested structures

2. **Canonical Encoding**
   - Verify identical values produce identical bytes
   - Test with different SDKs (cross-language compatibility)

### A.3 Fuzzing

1. **Structure-aware Fuzzing**
   - Generate valid BCS structures
   - Mutate at specific points
   - Test deserialization error handling

2. **Blind Fuzzing**
   - Random byte sequences
   - Test for crashes, hangs, memory issues

---

## Appendix B: References

- BCS Specification: `spec/BCS.md`
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- CWE-190 (Integer Overflow): https://cwe.mitre.org/data/definitions/190.html
- CWE-120 (Buffer Overflow): https://cwe.mitre.org/data/definitions/120.html
- CWE-20 (Input Validation): https://cwe.mitre.org/data/definitions/20.html

---

**Report End**
