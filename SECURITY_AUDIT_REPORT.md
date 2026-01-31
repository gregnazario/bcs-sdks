# Security Audit Report: BCS SDK Implementations

**Date:** January 30, 2026  
**Scope:** TypeScript, Python, Ruby, Dart, and C# BCS SDK implementations  
**Focus Areas:** Integer overflows, buffer overflows, input validation, DoS vectors, type confusion

---

## Executive Summary

This audit identified **5 Critical/High severity** and **2 Medium severity** security vulnerabilities across the BCS SDK implementations. The most critical issues involve integer overflow in capacity calculations and incorrect ULEB128 overflow validation.

---

## Critical Severity Issues

### 1. C# ULEB128 Overflow Check Logic Error
**File:** `sdks/csharp/Bcs/Uleb128.cs`  
**Line:** 105  
**Severity:** Critical  
**CWE:** CWE-190 (Integer Overflow or Wraparound)

**Description:**
The ULEB128 overflow check on line 105 is incorrect:
```csharp
if (b >= 0x10)
{
    throw BcsException.Uleb128Overflow();
}
```

This checks only the raw byte value, not the accumulated value after bit shifting. A malicious input could encode a value exceeding `uint.MaxValue` (0xFFFFFFFF) without triggering this check.

**Impact:**
- Integer overflow leading to incorrect deserialized values
- Potential for type confusion attacks
- Data corruption in downstream processing

**Proof of Concept:**
A 5-byte ULEB128 encoding with bytes `[0xFF, 0xFF, 0xFF, 0xFF, 0x0F]` would pass the `b >= 0x10` check but decode to a value exceeding u32 max.

**Recommended Fix:**
```csharp
// Check for overflow (5 bytes max for u32)
if (bytesConsumed == 5)
{
    var digit = (uint)(b & 0x7F);
    value |= digit << shift;
    
    // Check if final value exceeds u32 max
    if (value > MaxU32)
    {
        throw BcsException.Uleb128Overflow();
    }
    
    // Also check for continuation bit (should not be set on 5th byte)
    if ((b & 0x80) != 0)
    {
        throw BcsException.Uleb128Overflow();
    }
    
    return;
}
```

---

### 2. C# Buffer Capacity Integer Overflow
**File:** `sdks/csharp/Bcs/BcsSerializer.cs`  
**Line:** 477  
**Severity:** Critical  
**CWE:** CWE-190 (Integer Overflow or Wraparound)

**Description:**
The `EnsureCapacity` method calculates new capacity without checking for integer overflow:
```csharp
var newCapacity = Math.Max(_buffer.Length + (_buffer.Length >> 1), required);
```

If `_buffer.Length` is large (e.g., > 1.4 billion), the addition `_buffer.Length + (_buffer.Length >> 1)` can overflow, resulting in a negative or wrapped value.

**Impact:**
- Buffer allocation with incorrect size
- Potential `OutOfMemoryException` or `ArgumentOutOfRangeException`
- Application crash or denial of service

**Recommended Fix:**
```csharp
private void EnsureCapacity(int additional)
{
    var required = _size + additional;
    if (required < 0) // Check for overflow
    {
        throw BcsException.ExceededMaxLength((ulong)required);
    }
    if (required > _buffer.Length)
    {
        // Check for overflow before addition
        var growth = _buffer.Length >> 1;
        var newCapacity = (long)_buffer.Length + growth;
        if (newCapacity > int.MaxValue)
        {
            newCapacity = int.MaxValue;
        }
        newCapacity = Math.Max(newCapacity, required);
        
        if (newCapacity > int.MaxValue)
        {
            throw BcsException.ExceededMaxLength((ulong)newCapacity);
        }
        
        Array.Resize(ref _buffer, (int)newCapacity);
    }
}
```

---

### 3. TypeScript Buffer Capacity Multiplication Overflow
**File:** `sdks/typescript/src/serializer.ts`  
**Line:** 73  
**Severity:** High  
**CWE:** CWE-190 (Integer Overflow or Wraparound)

**Description:**
The capacity doubling operation can overflow before the check:
```typescript
let newCapacity = this.buffer.length * 2;
if (newCapacity > Number.MAX_SAFE_INTEGER) {
    newCapacity = Number.MAX_SAFE_INTEGER;
}
```

In JavaScript, if `buffer.length` is large, `buffer.length * 2` can exceed `Number.MAX_SAFE_INTEGER` (2^53 - 1), causing precision loss or `Infinity`.

**Impact:**
- Incorrect buffer size allocation
- Potential memory exhaustion
- Precision loss in capacity calculations

**Recommended Fix:**
```typescript
private ensureCapacity(needed: number): void {
    // Check for overflow before addition
    if (needed > Number.MAX_SAFE_INTEGER - this.size) {
        throw BcsError.exceededMaxLength(needed);
    }
    const required = this.size + needed;
    if (required <= this.buffer.length) return;

    // Check for overflow before multiplication
    let newCapacity: number;
    if (this.buffer.length > Number.MAX_SAFE_INTEGER / 2) {
        // Doubling would overflow, use required size
        newCapacity = required;
    } else {
        newCapacity = this.buffer.length * 2;
        if (newCapacity > Number.MAX_SAFE_INTEGER) {
            newCapacity = Number.MAX_SAFE_INTEGER;
        }
    }
    if (newCapacity < required) newCapacity = required;
    
    // Final check
    if (newCapacity > Number.MAX_SAFE_INTEGER) {
        throw BcsError.exceededMaxLength(newCapacity);
    }
    
    const newBuffer = new Uint8Array(newCapacity);
    newBuffer.set(this.buffer.subarray(0, this.size));
    this.buffer = newBuffer;
}
```

---

### 4. Dart Buffer Capacity Overflow Check Incomplete
**File:** `sdks/dart/lib/src/serializer.dart`  
**Line:** 32  
**Severity:** High  
**CWE:** CWE-190 (Integer Overflow or Wraparound)

**Description:**
The capacity doubling check is incomplete:
```dart
var newCapacity = _buffer.length * 2;
if (newCapacity < 0 || newCapacity < required) newCapacity = required;
```

While Dart integers are 64-bit, the check `newCapacity < 0` won't catch overflow (it would wrap to a large positive number). The multiplication can still overflow if `_buffer.length` is very large.

**Impact:**
- Incorrect buffer allocation size
- Potential memory issues

**Recommended Fix:**
```dart
void _ensureCapacity(int needed) {
    // Check for overflow before addition
    if (needed > maxSequenceLength - _size) {
        throw BcsError.exceededMaxLength(needed);
    }
    final required = _size + needed;
    if (required <= _buffer.length) return;

    // Check for overflow before multiplication
    int newCapacity;
    if (_buffer.length > (maxSequenceLength ~/ 2)) {
        // Doubling would exceed max, use required size
        newCapacity = required;
    } else {
        newCapacity = _buffer.length * 2;
        if (newCapacity < required) newCapacity = required;
    }
    
    // Ensure we don't exceed maxSequenceLength
    if (newCapacity > maxSequenceLength) {
        throw BcsError.exceededMaxLength(newCapacity);
    }
    
    final newBuffer = Uint8List(newCapacity);
    newBuffer.setRange(0, _size, _buffer);
    _buffer = newBuffer;
}
```

---

## High Severity Issues

### 5. DoS via Large Vector Pre-allocation
**Files:**
- `sdks/python/src/bcs/deserializer.py:478`
- `sdks/typescript/src/deserializer.ts:308`
- `sdks/dart/lib/src/deserializer.dart:277`
- `sdks/csharp/Bcs/BcsDeserializer.cs:264`
- `sdks/ruby/lib/bcs/deserializer.rb:241`

**Severity:** High  
**CWE:** CWE-400 (Uncontrolled Resource Consumption)

**Description:**
Multiple implementations pre-allocate arrays/lists with a length from ULEB128 without considering memory constraints. While `MAX_SEQUENCE_LENGTH` (2^31 - 1) limits the length, allocating arrays of that size can exhaust memory.

**Example (Python):**
```python
result: list[T] = [None] * length  # type: ignore
```

**Impact:**
- Memory exhaustion leading to denial of service
- Application crash or OOM errors
- Resource exhaustion attacks

**Recommended Fix:**
Add a configurable `max_alloc` parameter (already present in Python) and enforce reasonable defaults:

**Python (already has max_alloc, but should be lower default):**
```python
# Change default from MAX_SEQUENCE_LENGTH to something reasonable
self._max_alloc = max_alloc if max_alloc is not None else min(MAX_SEQUENCE_LENGTH, 10_000_000)  # 10MB default
```

**TypeScript:**
```typescript
readVector<T>(deserializer: (des: BcsDeserializer) => T): T[] {
    const length = this.readUleb128();
    if (length > MAX_SEQUENCE_LENGTH || !Number.isSafeInteger(length)) {
        throw BcsError.exceededMaxLength(length);
    }
    
    // Add memory limit check
    const MAX_VECTOR_LENGTH = 10_000_000; // ~10M elements
    if (length > MAX_VECTOR_LENGTH) {
        throw BcsError.exceededMaxLength(length);
    }
    
    const result: T[] = new Array(length);
    for (let i = 0; i < length; i++) {
        result[i] = deserializer(this);
    }
    return result;
}
```

**Dart:**
```dart
List<T> readVector<T>(T Function(BcsDeserializer) deserializer) {
    final length = readUleb128();
    _checkSequenceLength(length);
    
    // Add memory limit check
    const maxVectorLength = 10000000; // ~10M elements
    if (length > maxVectorLength) {
        throw BcsError.exceededMaxLength(length, maxVectorLength);
    }
    
    final result = List<T>.filled(length, null as T, growable: false);
    for (var i = 0; i < length; i++) {
        result[i] = deserializer(this);
    }
    return result;
}
```

**C#:**
```csharp
public List<T> ReadVector<T>(Func<BcsDeserializer, T> deserializer)
{
    var length = ReadVectorLength();
    
    // Add memory limit check
    const int MaxVectorLength = 10_000_000; // ~10M elements
    if (length > MaxVectorLength)
    {
        throw BcsException.ExceededMaxLength(length);
    }
    
    var result = new List<T>((int)length);
    for (var i = 0u; i < length; i++)
    {
        result.Add(deserializer(this));
    }
    return result;
}
```

**Ruby:**
```ruby
def read_vector(&deserializer)
    length = read_uleb128
    check_sequence_length(length)
    
    # Add memory limit check
    max_vector_length = 10_000_000
    raise Error.exceeded_max_length(length) if length > max_vector_length
    
    Array.new(length) { deserializer.call(self) }
end
```

---

## Medium Severity Issues

### 6. Python read_vector_u64 Integer Division Edge Case
**File:** `sdks/python/src/bcs/deserializer.py`  
**Line:** 502  
**Severity:** Medium  
**CWE:** CWE-682 (Incorrect Calculation)

**Description:**
The overflow check uses integer division which could miss edge cases:
```python
if length > available // 8:
    raise UnexpectedEof(length * 8, available)
```

If `available` is not divisible by 8, the check might allow reading more bytes than available.

**Impact:**
- Potential buffer over-read
- Incorrect deserialization

**Recommended Fix:**
```python
# Check available bytes before computing byte_length to prevent overflow
available = self._len - self._offset
byte_length = length * 8
if byte_length > available:
    raise UnexpectedEof(byte_length, available)
```

---

### 7. TypeScript readVector Missing Safe Integer Check
**File:** `sdks/typescript/src/deserializer.ts`  
**Line:** 304  
**Severity:** Medium  
**CWE:** CWE-190 (Integer Overflow or Wraparound)

**Description:**
While there is a `Number.isSafeInteger` check, it's only checked after reading the ULEB128. The ULEB128 decoder should also validate that the decoded value is a safe integer.

**Current Code:**
```typescript
if (length > MAX_SEQUENCE_LENGTH || !Number.isSafeInteger(length)) {
    throw BcsError.exceededMaxLength(length);
}
```

**Impact:**
- If ULEB128 decodes to a value > Number.MAX_SAFE_INTEGER, array allocation could fail or behave unexpectedly

**Note:** This is partially mitigated by the check, but the ULEB128 decoder should also validate the result is a safe integer.

---

## Low Severity / Informational Issues

### 8. Ruby Array Batch Operations - Good Practice
**File:** `sdks/ruby/lib/bcs/deserializer.rb`  
**Lines:** 266-268

**Description:**
Ruby correctly implements overflow prevention for batch array operations using `MAX_*_ARRAY_LENGTH` constants. This is a good practice that should be replicated in other languages.

**Recommendation:**
Consider adding similar constants and checks in other SDK implementations for consistency and defense-in-depth.

---

## Summary of Findings

| Severity | Count | Issues |
|----------|-------|--------|
| Critical | 2 | C# ULEB128 overflow check, C# buffer capacity overflow |
| High | 3 | TypeScript capacity overflow, Dart capacity overflow, DoS via pre-allocation |
| Medium | 2 | Python integer division edge case, TypeScript safe integer validation |
| Low | 1 | Informational (Ruby good practice) |

---

## Recommendations

1. **Immediate Actions:**
   - Fix C# ULEB128 overflow check (Critical)
   - Fix C# buffer capacity overflow (Critical)
   - Add overflow checks before multiplication in TypeScript and Dart

2. **Short-term Actions:**
   - Implement configurable memory limits for vector allocations
   - Add comprehensive integer overflow tests
   - Review all arithmetic operations for overflow potential

3. **Long-term Actions:**
   - Consider using safe arithmetic libraries or compiler flags
   - Implement fuzzing for integer overflow scenarios
   - Add static analysis tools to catch overflow issues

---

## Testing Recommendations

1. **Fuzz Testing:**
   - Test ULEB128 decoding with values near u32 max
   - Test buffer growth with large initial capacities
   - Test vector deserialization with lengths near MAX_SEQUENCE_LENGTH

2. **Unit Tests:**
   - Test capacity doubling at various buffer sizes
   - Test ULEB128 overflow edge cases
   - Test vector allocation with maximum allowed lengths

3. **Integration Tests:**
   - Test deserialization of malicious inputs
   - Test memory exhaustion scenarios
   - Test concurrent deserialization with large inputs

---

## References

- [CWE-190: Integer Overflow or Wraparound](https://cwe.mitre.org/data/definitions/190.html)
- [CWE-400: Uncontrolled Resource Consumption](https://cwe.mitre.org/data/definitions/400.html)
- [CWE-682: Incorrect Calculation](https://cwe.mitre.org/data/definitions/682.html)
- [OWASP Top 10: A03:2021 – Injection](https://owasp.org/Top10/A03_2021-Injection/)

---

**Report Generated:** January 30, 2026  
**Auditor:** Security Audit Agent
