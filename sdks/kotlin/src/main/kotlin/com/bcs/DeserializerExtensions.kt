/**
 * Kotlin extension functions for BcsDeserializer
 */
package com.bcs

import java.math.BigInteger

// =============================================================================
// Kotlin-style Nullable Support
// =============================================================================

/**
 * Read an optional value using Kotlin's null safety
 *
 * @param deserializer function to deserialize the value if present
 * @return the value or null
 */
inline fun <T : Any> BcsDeserializer.readOption(
    deserializer: BcsDeserializer.() -> T
): T? {
    return when (readU8()) {
        0 -> null
        1 -> deserializer()
        else -> throw BcsError.invalidOption(2)
    }
}

/**
 * Read an optional primitive with automatic type inference
 */
fun BcsDeserializer.readOptionU8(): Int? = readOption { readU8() }
fun BcsDeserializer.readOptionU16(): Int? = readOption { readU16() }
fun BcsDeserializer.readOptionU32(): Long? = readOption { readU32() }
fun BcsDeserializer.readOptionU64(): Long? = readOption { readU64() }
fun BcsDeserializer.readOptionString(): String? = readOption { readString() }
fun BcsDeserializer.readOptionBool(): Boolean? = readOption { readBool() }

// =============================================================================
// Collection Extensions
// =============================================================================

/**
 * Read a list with element deserializer
 *
 * @param deserializer function to deserialize each element
 * @return the list of deserialized values
 */
inline fun <T> BcsDeserializer.readList(
    deserializer: BcsDeserializer.() -> T
): List<T> {
    val length = readUleb128().toInt()
    return List(length) { deserializer() }
}

/**
 * Read a mutable list with element deserializer
 */
inline fun <T> BcsDeserializer.readMutableList(
    deserializer: BcsDeserializer.() -> T
): MutableList<T> {
    val length = readUleb128().toInt()
    return MutableList(length) { deserializer() }
}

/**
 * Read a ByteArray from a vector
 */
fun BcsDeserializer.readByteList(): ByteArray {
    val length = readUleb128().toInt()
    return ByteArray(length) { readU8().toByte() }
}

/**
 * Read a list of u8 values
 */
fun BcsDeserializer.readU8List(): List<Int> = readList { readU8() }

/**
 * Read a list of u16 values
 */
fun BcsDeserializer.readU16List(): List<Int> = readList { readU16() }

/**
 * Read a list of u32 values
 */
fun BcsDeserializer.readU32List(): List<Long> = readList { readU32() }

/**
 * Read a list of u64 values
 */
fun BcsDeserializer.readU64List(): List<Long> = readList { readU64() }

/**
 * Read a list of strings
 */
fun BcsDeserializer.readStringList(): List<String> = readList { readString() }

// =============================================================================
// Map Extensions
// =============================================================================

/**
 * Compare two byte arrays lexicographically (as unsigned bytes)
 * Made internal for access from inline extension functions.
 */
@PublishedApi
internal fun compareBytesUnsigned(a: ByteArray, b: ByteArray): Int {
    val minLen = minOf(a.size, b.size)
    for (i in 0 until minLen) {
        val cmp = (a[i].toInt() and 0xFF) - (b[i].toInt() and 0xFF)
        if (cmp != 0) return cmp
    }
    return a.size - b.size
}

/**
 * Read a map with key/value deserializers (validates sorted keys per BCS spec)
 *
 * BCS maps MUST have keys sorted by their serialized byte representation.
 * This function validates that keys are in sorted order and rejects duplicates.
 *
 * @param keyDeserializer function to deserialize keys
 * @param valueDeserializer function to deserialize values
 * @return the deserialized map
 * @throws BcsError.NonCanonicalMap if keys are not sorted or duplicates exist
 */
inline fun <K, V> BcsDeserializer.readMap(
    keyDeserializer: BcsDeserializer.() -> K,
    valueDeserializer: BcsDeserializer.() -> V
): Map<K, V> {
    val length = readUleb128().toInt()
    if (length > BcsConstants.MAX_SEQUENCE_LENGTH) {
        throw BcsError.exceededMaxLength(length)
    }
    
    val result = linkedMapOf<K, V>()
    var prevKeyBytes: ByteArray? = null

    repeat(length) {
        // Record position before reading key
        val keyStart = offset
        
        // Deserialize the key
        val key = keyDeserializer()
        
        // Get key bytes for ordering validation
        val keyEnd = offset
        val keyBytes = getDataSlice(keyStart, keyEnd)

        // Verify key order (BCS requires sorted keys)
        prevKeyBytes?.let { prev ->
            val cmp = compareBytesUnsigned(prev, keyBytes)
            if (cmp == 0) {
                throw BcsError.nonCanonicalMap("duplicate key")
            }
            if (cmp > 0) {
                throw BcsError.nonCanonicalMap("keys not sorted")
            }
        }
        prevKeyBytes = keyBytes

        // Read value
        val value = valueDeserializer()
        result[key] = value
    }

    return result
}

/**
 * Read a mutable map with key/value deserializers (validates sorted keys per BCS spec)
 *
 * BCS maps MUST have keys sorted by their serialized byte representation.
 * This function validates that keys are in sorted order and rejects duplicates.
 *
 * @param keyDeserializer function to deserialize keys
 * @param valueDeserializer function to deserialize values
 * @return the deserialized mutable map
 * @throws BcsError.NonCanonicalMap if keys are not sorted or duplicates exist
 */
inline fun <K, V> BcsDeserializer.readMutableMap(
    keyDeserializer: BcsDeserializer.() -> K,
    valueDeserializer: BcsDeserializer.() -> V
): MutableMap<K, V> {
    val length = readUleb128().toInt()
    if (length > BcsConstants.MAX_SEQUENCE_LENGTH) {
        throw BcsError.exceededMaxLength(length)
    }
    
    val result = linkedMapOf<K, V>()
    var prevKeyBytes: ByteArray? = null

    repeat(length) {
        // Record position before reading key
        val keyStart = offset
        
        // Deserialize the key
        val key = keyDeserializer()
        
        // Get key bytes for ordering validation
        val keyEnd = offset
        val keyBytes = getDataSlice(keyStart, keyEnd)

        // Verify key order (BCS requires sorted keys)
        prevKeyBytes?.let { prev ->
            val cmp = compareBytesUnsigned(prev, keyBytes)
            if (cmp == 0) {
                throw BcsError.nonCanonicalMap("duplicate key")
            }
            if (cmp > 0) {
                throw BcsError.nonCanonicalMap("keys not sorted")
            }
        }
        prevKeyBytes = keyBytes

        // Read value
        val value = valueDeserializer()
        result[key] = value
    }

    return result
}

/**
 * Read a Map<String, V> with a value deserializer
 */
inline fun <V> BcsDeserializer.readStringMap(
    valueDeserializer: BcsDeserializer.() -> V
): Map<String, V> = readMap({ readString() }, valueDeserializer)

/**
 * Read a Map<Int, V> (u8 keys) with a value deserializer
 */
inline fun <V> BcsDeserializer.readU8Map(
    valueDeserializer: BcsDeserializer.() -> V
): Map<Int, V> = readMap({ readU8() }, valueDeserializer)

// =============================================================================
// Struct/Container Support
// =============================================================================

/**
 * Read a struct using a block
 *
 * @param block the deserialization block for struct fields
 * @return the result of the block
 */
inline fun <T> BcsDeserializer.readStruct(block: BcsDeserializer.() -> T): T {
    enterStruct()
    val result = block()
    leaveStruct()
    return result
}

/**
 * Read an enum variant
 *
 * @param block function that receives the variant index and returns the value
 * @return the result of the block
 */
inline fun <T> BcsDeserializer.readEnum(block: BcsDeserializer.(Int) -> T): T {
    val variantIndex = enterEnum()
    val result = block(variantIndex)
    leaveEnum()
    return result
}

// =============================================================================
// BigInteger Support
// =============================================================================

/**
 * Read a u128 as BigInteger
 */
fun BcsDeserializer.readU128AsBigInteger(): BigInteger {
    val bytes = readFixedBytes(16)
    // Convert from little-endian to big-endian
    val bigEndian = bytes.reversedArray()
    return BigInteger(1, bigEndian)
}

/**
 * Read a u256 as BigInteger
 */
fun BcsDeserializer.readU256AsBigInteger(): BigInteger {
    val bytes = readFixedBytes(32)
    // Convert from little-endian to big-endian
    val bigEndian = bytes.reversedArray()
    return BigInteger(1, bigEndian)
}

/**
 * Read an i128 as BigInteger
 */
fun BcsDeserializer.readI128AsBigInteger(): BigInteger {
    val bytes = readFixedBytes(16)
    // Convert from little-endian to big-endian
    val bigEndian = bytes.reversedArray()
    val unsigned = BigInteger(1, bigEndian)

    // Check if negative (high bit set)
    val signBit = BigInteger.ONE.shiftLeft(127)
    return if (unsigned >= signBit) {
        unsigned.subtract(BigInteger.ONE.shiftLeft(128))
    } else {
        unsigned
    }
}

/**
 * Read an i256 as BigInteger
 */
fun BcsDeserializer.readI256AsBigInteger(): BigInteger {
    val bytes = readFixedBytes(32)
    // Convert from little-endian to big-endian
    val bigEndian = bytes.reversedArray()
    val unsigned = BigInteger(1, bigEndian)

    // Check if negative (high bit set)
    val signBit = BigInteger.ONE.shiftLeft(255)
    return if (unsigned >= signBit) {
        unsigned.subtract(BigInteger.ONE.shiftLeft(256))
    } else {
        unsigned
    }
}

// =============================================================================
// Convenience Properties
// =============================================================================

/**
 * Check if there's more data to read
 */
val BcsDeserializer.hasRemaining: Boolean
    get() = remaining() > 0

/**
 * Check if at end of data
 */
val BcsDeserializer.isAtEnd: Boolean
    get() = remaining() == 0
