# BCS SDK Audit Report

**Generated**: 2026-01-28  
**Auditor**: Comprehensive Security & Functionality Review  
**SDKs Reviewed**: 15 (C, C++, C#, Dart, Elixir, Go, Java, Kotlin, OCaml, Python, Ruby, Rust, Swift, TypeScript, Zig)

---

## Executive Summary

This report provides a comprehensive security and functionality audit of all 15 BCS (Binary Canonical Serialization) SDK implementations.

### Key Findings

| Category | Status |
|----------|--------|
| Critical Security Issues | 0 |
| High Severity Issues | 0 |
| Medium Severity Issues | 4 (map helpers only in C/C#/Go/Zig) |
| SDKs with Full Test Pass | **15/15** |
| SDKs with Full Security Features | 11/15 |

### Security Compliance Summary

All 15 SDKs implement the core BCS security features:
- Boolean validation (reject non 0/1)
- Option tag validation (reject non 0/1)
- ULEB128 validation (non-canonical rejection, overflow protection)
- UTF-8 validation
- Container depth tracking (MAX_CONTAINER_DEPTH = 500)
- Remaining input check

**4 SDKs have partial map support** (helpers only, no automatic validation):
- C, C#, Go, Zig

---

## Test Results Summary

All 15 SDKs pass their test suites.

| SDK | Tests | Status | Framework |
|-----|-------|--------|-----------|
| **Python** | 150 | ✅ PASS | pytest |
| **Elixir** | 218 | ✅ PASS | ExUnit (30 doctests + 188 tests) |
| **Swift** | 68 | ✅ PASS | XCTest |
| **Dart** | 62 | ✅ PASS | dart test |
| **Rust** | 58 | ✅ PASS | cargo test (47 + 2 + 9 doc tests) |
| **Ruby** | 53 | ✅ PASS | Minitest (135 assertions) |
| **Java** | 52 | ✅ PASS | JUnit 5 |
| **TypeScript** | 48 | ✅ PASS | Vitest |
| **OCaml** | 39 | ✅ PASS | Alcotest |
| **C#** | 35 | ✅ PASS | .NET Test |
| **C++** | 28 | ✅ PASS | Doctest (1 skipped) |
| **C** | All | ✅ PASS | Custom runner |
| **Go** | All | ✅ PASS | go test |
| **Kotlin** | All | ✅ PASS | Gradle/JUnit |
| **Zig** | All | ✅ PASS | zig build test |

### Test Coverage by Category

**Strong Coverage (100+ tests):**
- Python: 150 tests with comprehensive test vectors
- Elixir: 218 tests with doctests

**Good Coverage (50+ tests):**
- Swift: 68 tests
- Dart: 62 tests
- Rust: 58 tests
- Ruby: 53 tests (135 assertions)
- Java: 52 tests

**Standard Coverage (30-50 tests):**
- TypeScript: 48 tests
- OCaml: 39 tests
- C#: 35 tests
- C++: 28 tests

---

## Security Feature Matrix

| Feature | C | C++ | C# | Dart | Elixir | Go | Java | Kotlin | OCaml | Python | Ruby | Rust | Swift | TS | Zig |
|---------|---|-----|----|----|--------|----|----|--------|-------|--------|------|------|-------|----|----|
| Boolean Validation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Option Validation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ULEB128 Validation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| UTF-8 Validation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Depth Tracking | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Map Validation | ⚠️ | ✅ | ⚠️ | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| Remaining Input | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| u128/i128 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| u256/i256 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |

**Legend:** ✅ = Full, ⚠️ = Partial (helpers only), ❌ = Not supported

---

## Security Validation Details

### Boolean Validation

All SDKs properly reject boolean values that are not 0x00 or 0x01.

| SDK | Implementation |
|-----|----------------|
| C | `bcs_read_bool()` returns `BCS_ERR_INVALID_BOOLEAN` |
| C++ | `read_bool()` throws `Error::invalid_boolean()` |
| C# | `ReadBool()` throws `BcsException.InvalidBoolean()` |
| Dart | `readBool()` throws `BcsError.invalidBoolean()` |
| Elixir | `read_bool()` returns `{:error, Error.invalid_boolean}` |
| Go | `ReadBool()` panics with `InvalidBoolean` |
| Java | `readBool()` throws `BcsError.invalidBoolean()` |
| Kotlin | `readBool()` throws `BcsError.invalidBoolean()` |
| OCaml | `read_bool` raises `Bcs_error (Invalid_boolean b)` |
| Python | `read_bool()` raises `InvalidBoolean` |
| Ruby | `read_bool` raises `Error.invalid_boolean` |
| Rust | `parse_bool()` returns `Err(Error::InvalidBoolean)` |
| Swift | `readBool()` throws `BcsError.invalidBoolean` |
| TypeScript | `readBool()` throws `BcsError.invalidBoolean()` |
| Zig | `readBool()` returns `error.InvalidBoolean` |

### ULEB128 Validation

All SDKs implement both non-canonical rejection and overflow protection:

| SDK | Non-Canonical | Overflow | Notes |
|-----|---------------|----------|-------|
| C | ✅ Line 619 | ✅ Line 623 | Returns error codes |
| C++ | ✅ Line 111 | ✅ Line 115 | Throws exceptions |
| C# | ✅ Lines 119-122 | ✅ Lines 103-108 | 5-byte limit |
| Dart | ✅ Lines 74-89 | ✅ | Throws BcsError |
| Elixir | ✅ Lines 91-122 | ✅ Lines 116-128 | Returns error tuple |
| Go | ✅ Lines 78-81 | ✅ Lines 63-70 | Panics |
| Java | ✅ Lines 117-138 | ✅ Lines 115-127 | Throws exception |
| Kotlin | ✅ Lines 100-102 | ✅ Lines 105-116 | Throws exception |
| OCaml | ✅ Line 88 | ✅ Lines 80, 90 | Raises exception |
| Python | ✅ Lines 319-320 | ✅ Lines 323-332 | Raises exception |
| Ruby | ✅ Line 93 | ✅ Lines 96-105 | Raises exception |
| Rust | ✅ Lines 199-203 | ✅ Lines 205-210 | Returns Result |
| Swift | ✅ Lines 183-185 | ✅ Lines 188-199 | Throws error |
| TypeScript | ✅ Lines 112-114 | ✅ Lines 116-126 | Throws error |
| Zig | ✅ Lines 118-120 | ✅ Line 125 | Returns error |

### Container Depth Tracking

All SDKs enforce `MAX_CONTAINER_DEPTH = 500`:

| SDK | Constant Location | Enforcement Method |
|-----|-------------------|-------------------|
| C | `bcs.h` line 27 | `bcs_des_enter_struct()` |
| C++ | `types.hpp` line 16 | `enter_container()` |
| C# | `BcsSerializer.cs` line 30 | `EnterContainer()` |
| Dart | `constants.dart` line 10 | `_enterContainer()` |
| Elixir | `deserializer.ex` line 34 | `check_depth()` |
| Go | `serializer.go` line 15 | `enterContainer()` |
| Java | `BcsSerializer.java` line 30 | `enterContainer()` |
| Kotlin | `Bcs.kt` line 18 | `enterContainer()` |
| OCaml | `bcs.ml` line 8 | `enter_struct` |
| Python | `types.py` line 12 | `_check_depth()` |
| Ruby | `constants.rb` line 8 | `enter_container` |
| Rust | `lib.rs` line 315 | `enter_named_container()` |
| Swift | `Constants.swift` line 14 | `enterContainer()` |
| TypeScript | `serializer.ts` line 34 | `enterContainer()` |
| Zig | `bcs.zig` line 39 | `enterContainer()` |

### Map Validation

| SDK | Full API | Key Sorting | Duplicate Rejection | Notes |
|-----|----------|-------------|---------------------|-------|
| C | ⚠️ Helpers | Manual | Manual | `bcs_compare_bytes()` provided |
| C++ | ✅ | ✅ | ✅ | `read_map()` fully validates |
| C# | ⚠️ Helpers | Manual | Manual | `ReadMapLength()` only |
| Dart | ✅ | ✅ | ✅ | `readMap()` fully validates |
| Elixir | ✅ | ✅ | ✅ | `read_map()` fully validates |
| Go | ⚠️ Helpers | Manual | Manual | `SortMapEntries()` helper |
| Java | ✅ | ✅ | ✅ | `readMap()` fully validates |
| Kotlin | ✅ | ✅ | ✅ | `readMap()` fully validates |
| OCaml | ✅ | ✅ | ✅ | `read_map` fully validates |
| Python | ✅ | ✅ | ✅ | `read_map()` fully validates |
| Ruby | ✅ | ✅ | ✅ | `read_map` fully validates |
| Rust | ✅ | ✅ | ✅ | Via Serde, validates ordering |
| Swift | ✅ | ✅ | ✅ | `readMap()` fully validates |
| TypeScript | ✅ | ✅ | ✅ | `readMap()` fully validates |
| Zig | ⚠️ Helpers | Manual | Manual | `compareBytes()` provided |

---

## Feature Completeness Matrix

| Feature | C | C++ | C# | Dart | Elixir | Go | Java | Kotlin | OCaml | Python | Ruby | Rust | Swift | TS | Zig |
|---------|---|-----|----|----|--------|----|----|--------|-------|--------|------|------|-------|----|----|
| bool | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| u8-u64 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| u128 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| u256 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| i8-i64 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| i128 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| i256 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| ULEB128 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Strings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bytes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Option | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vector | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fixed Array | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Maps | ⚠️ | ✅ | ⚠️ | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| Structs | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Enums | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Legend:** ✅ = Full, ⚠️ = Partial/Helpers, ❌ = Not Supported

---

## Large Integer Support Details

| SDK | u128 Type | u256 Type | i128 Type | i256 Type |
|-----|-----------|-----------|-----------|-----------|
| C | `uint8_t[16]` | `uint8_t[32]` | `uint8_t[16]` | `uint8_t[32]` |
| C++ | `std::array<uint8_t,16>` | `std::array<uint8_t,32>` | `std::array<uint8_t,16>` | `std::array<uint8_t,32>` |
| C# | `BigInteger` | `BigInteger` | `BigInteger` | `BigInteger` |
| Dart | `BigInt` | `BigInt` | `BigInt` | `BigInt` |
| Elixir | Native integer | Native integer | Native integer | Native integer |
| Go | `*big.Int` | `*big.Int` | `*big.Int` | `*big.Int` |
| Java | `BigInteger` | `BigInteger` | `BigInteger` | `BigInteger` |
| Kotlin | `BigInteger` | `BigInteger` | `BigInteger` | `BigInteger` |
| OCaml | `bytes` | `bytes` | `bytes` | `bytes` |
| Python | Native `int` | Native `int` | Native `int` | Native `int` |
| Ruby | Native `Integer` | Native `Integer` | Native `Integer` | Native `Integer` |
| Rust | Native `u128` | ❌ | Native `i128` | ❌ |
| Swift | `[UInt8]` | `[UInt8]` | `[UInt8]` | `[UInt8]` |
| TypeScript | `bigint` | `bigint` | `bigint` | `bigint` |
| Zig | Native `u128` | `[32]u8` | Native `i128` | `[32]u8` |

---

## SDK Security Ratings

| SDK | Rating | Notes |
|-----|--------|-------|
| **C++** | ⭐⭐⭐⭐⭐ | Complete implementation, all validations, template metaprogramming |
| **Java** | ⭐⭐⭐⭐⭐ | Complete with all validations, BigInteger support |
| **Kotlin** | ⭐⭐⭐⭐⭐ | Complete with all validations, extension functions |
| **Python** | ⭐⭐⭐⭐⭐ | Complete, configurable max_alloc defense |
| **Rust** | ⭐⭐⭐⭐⭐ | Serde integration, memory safe (missing u256/i256) |
| **Elixir** | ⭐⭐⭐⭐⭐ | Functional style, all validations, result tuples |
| **Ruby** | ⭐⭐⭐⭐⭐ | Complete, bignum support |
| **Dart** | ⭐⭐⭐⭐⭐ | Complete, zero-copy views |
| **Swift** | ⭐⭐⭐⭐⭐ | Complete, @inlinable optimizations |
| **TypeScript** | ⭐⭐⭐⭐⭐ | Complete, native bigint |
| **OCaml** | ⭐⭐⭐⭐⭐ | Complete, RFC 3629 UTF-8 validation |
| **C** | ⭐⭐⭐⭐ | Solid core, map helpers only (manual validation) |
| **C#** | ⭐⭐⭐⭐ | Complete core, map helpers only |
| **Go** | ⭐⭐⭐⭐ | Complete core, object pooling, map helpers only |
| **Zig** | ⭐⭐⭐⭐ | Complete core, comptime generics, map helpers only |

---

## Remaining Recommendations

### Medium Priority (Map Validation)

The following SDKs provide map helper functions but require manual key validation:

1. **C** - Has `bcs_compare_bytes()`, `bcs_deserializer_offset()`, `bcs_deserializer_data_at()`
2. **C#** - Has `ReadMapLength()` only
3. **Go** - Has `SortMapEntries()`, `ReadMapLen()`, `Position()`, `SliceFrom()`
4. **Zig** - Has `readMapLen()`, `writeMapLen()`, `compareBytes()`, `getSlice()`

**Recommendation**: Users of these SDKs must implement their own key validation when deserializing maps, or the SDK maintainers could add a `readMap()` function with automatic validation.

### Low Priority

1. **Rust**: Add u256/i256 support (currently not in standard library)
2. **All SDKs**: Add fuzz testing for additional security validation
3. **All SDKs**: Ensure test vectors from `bcs-comprehensive.json` are used

---

## Appendix: Test Commands

```bash
# Run all tests
make test

# Individual SDK tests
make test-python      # 150 tests
make test-typescript  # 48 tests  
make test-rust        # 58 tests
make test-go          # All tests
make test-java        # 52 tests
make test-kotlin      # All tests
make test-cpp         # 28 tests
make test-swift       # 68 tests
make test-c           # All tests
make test-ruby        # 53 tests
make test-dart        # 62 tests
make test-elixir      # 218 tests
make test-csharp      # 35 tests
make test-zig         # All tests
make test-ocaml       # 39 tests
```

---

*Report generated from comprehensive SDK analysis - 2026-01-28*
