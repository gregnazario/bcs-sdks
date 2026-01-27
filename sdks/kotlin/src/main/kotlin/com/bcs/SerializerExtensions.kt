/**
 * Kotlin extension functions for BcsSerializer
 */
package com.bcs

import java.math.BigInteger

// =============================================================================
// Operator Overloading for Builder Pattern
// =============================================================================

/**
 * Allows chaining with `+` operator: ser + { writeU8(42) }
 */
operator fun BcsSerializer.plus(block: BcsSerializer.() -> Unit): BcsSerializer {
    block()
    return this
}

// =============================================================================
// Infix Functions for Cleaner Syntax
// =============================================================================

/**
 * Write a u8: `ser write 42.toUByte()`
 */
infix fun BcsSerializer.write(value: UByte): BcsSerializer = writeU8(value.toInt())

/**
 * Write a u16: `ser write 1000.toUShort()`
 */
infix fun BcsSerializer.write(value: UShort): BcsSerializer = writeU16(value.toInt())

/**
 * Write a u32: `ser write 100000.toUInt()`
 */
infix fun BcsSerializer.write(value: UInt): BcsSerializer = writeU32(value.toLong())

/**
 * Write a u64: `ser write 100000UL`
 */
infix fun BcsSerializer.write(value: ULong): BcsSerializer = writeU64(value.toLong())

/**
 * Write a string: `ser write "hello"`
 */
infix fun BcsSerializer.write(value: String): BcsSerializer = writeString(value)

/**
 * Write a boolean: `ser write true`
 */
infix fun BcsSerializer.write(value: Boolean): BcsSerializer = writeBool(value)

// =============================================================================
// Kotlin-style Nullable Support
// =============================================================================

/**
 * Write an optional value using Kotlin's null safety
 *
 * @param value the optional value (null represents None)
 * @param serializer function to serialize the value if present
 */
inline fun <T : Any> BcsSerializer.writeOption(
    value: T?,
    serializer: BcsSerializer.(T) -> Unit
): BcsSerializer {
    if (value == null) {
        writeU8(0)
    } else {
        writeU8(1)
        serializer(value)
    }
    return this
}

/**
 * Write an optional primitive with automatic type inference
 */
fun BcsSerializer.writeOptionU8(value: Int?): BcsSerializer =
    writeOption(value) { writeU8(it) }

fun BcsSerializer.writeOptionU16(value: Int?): BcsSerializer =
    writeOption(value) { writeU16(it) }

fun BcsSerializer.writeOptionU32(value: Long?): BcsSerializer =
    writeOption(value) { writeU32(it) }

fun BcsSerializer.writeOptionU64(value: Long?): BcsSerializer =
    writeOption(value) { writeU64(it) }

fun BcsSerializer.writeOptionString(value: String?): BcsSerializer =
    writeOption(value) { writeString(it) }

fun BcsSerializer.writeOptionBool(value: Boolean?): BcsSerializer =
    writeOption(value) { writeBool(it) }

// =============================================================================
// Collection Extensions
// =============================================================================

/**
 * Write a list with element serializer
 *
 * @param list the list to serialize
 * @param serializer function to serialize each element
 */
inline fun <T> BcsSerializer.writeList(
    list: List<T>,
    serializer: BcsSerializer.(T) -> Unit
): BcsSerializer {
    writeUleb128(list.size)
    list.forEach { serializer(it) }
    return this
}

/**
 * Write an array with element serializer
 */
inline fun <T> BcsSerializer.writeArray(
    array: Array<T>,
    serializer: BcsSerializer.(T) -> Unit
): BcsSerializer {
    writeUleb128(array.size)
    array.forEach { serializer(it) }
    return this
}

/**
 * Write a ByteArray as a vector
 */
fun BcsSerializer.writeByteList(bytes: ByteArray): BcsSerializer {
    writeUleb128(bytes.size)
    bytes.forEach { writeU8(it.toInt() and 0xFF) }
    return this
}

/**
 * Write a list of u8 values
 */
fun BcsSerializer.writeU8List(values: List<Int>): BcsSerializer =
    writeList(values) { writeU8(it) }

/**
 * Write a list of u16 values
 */
fun BcsSerializer.writeU16List(values: List<Int>): BcsSerializer =
    writeList(values) { writeU16(it) }

/**
 * Write a list of u32 values
 */
fun BcsSerializer.writeU32List(values: List<Long>): BcsSerializer =
    writeList(values) { writeU32(it) }

/**
 * Write a list of u64 values
 */
fun BcsSerializer.writeU64List(values: List<Long>): BcsSerializer =
    writeList(values) { writeU64(it) }

/**
 * Write a list of strings
 */
fun BcsSerializer.writeStringList(values: List<String>): BcsSerializer =
    writeList(values) { writeString(it) }

// =============================================================================
// Map Extensions
// =============================================================================

/**
 * Write a map with key/value serializers (sorted by serialized key bytes)
 *
 * @param map the map to serialize
 * @param keySerializer function to serialize keys
 * @param valueSerializer function to serialize values
 */
inline fun <K, V> BcsSerializer.writeMap(
    map: Map<K, V>,
    keySerializer: BcsSerializer.(K) -> Unit,
    valueSerializer: BcsSerializer.(V) -> Unit
): BcsSerializer {
    // Serialize all keys to get their byte representation for sorting
    val entries = map.entries.map { (key, value) ->
        val keyBytes = bcsSerialize { keySerializer(key) }
        Triple(keyBytes, key, value)
    }

    // Sort by key bytes (lexicographic)
    val sortedEntries = entries.sortedWith { a, b ->
        val aBytes = a.first
        val bBytes = b.first
        for (i in 0 until minOf(aBytes.size, bBytes.size)) {
            val cmp = (aBytes[i].toInt() and 0xFF) - (bBytes[i].toInt() and 0xFF)
            if (cmp != 0) return@sortedWith cmp
        }
        aBytes.size - bBytes.size
    }

    // Write length and entries
    writeUleb128(sortedEntries.size)
    sortedEntries.forEach { (keyBytes, _, value) ->
        writeFixedBytes(keyBytes, keyBytes.size)
        valueSerializer(value)
    }

    return this
}

/**
 * Write a Map<String, V> with a value serializer
 */
inline fun <V> BcsSerializer.writeStringMap(
    map: Map<String, V>,
    valueSerializer: BcsSerializer.(V) -> Unit
): BcsSerializer = writeMap(map, { writeString(it) }, valueSerializer)

/**
 * Write a Map<Int, V> (u8 keys) with a value serializer
 */
inline fun <V> BcsSerializer.writeU8Map(
    map: Map<Int, V>,
    valueSerializer: BcsSerializer.(V) -> Unit
): BcsSerializer = writeMap(map, { writeU8(it) }, valueSerializer)

// =============================================================================
// Struct/Container Support
// =============================================================================

/**
 * Write a struct using a block
 *
 * @param block the serialization block for struct fields
 */
inline fun BcsSerializer.writeStruct(block: BcsSerializer.() -> Unit): BcsSerializer {
    enterStruct()
    block()
    leaveStruct()
    return this
}

/**
 * Write an enum variant
 *
 * @param variantIndex the variant index
 * @param block the serialization block for variant data
 */
inline fun BcsSerializer.writeEnum(
    variantIndex: Int,
    block: BcsSerializer.() -> Unit = {}
): BcsSerializer {
    enterEnum(variantIndex)
    block()
    leaveEnum()
    return this
}

// =============================================================================
// BigInteger Support
// =============================================================================

/**
 * Write a u128 from BigInteger
 */
fun BcsSerializer.writeU128(value: BigInteger): BcsSerializer {
    require(value >= BigInteger.ZERO) { "u128 must be non-negative" }
    require(value < BigInteger.TWO.pow(128)) { "u128 overflow" }

    val bytes = ByteArray(16)
    val valueBytes = value.toByteArray()

    // Convert from big-endian to little-endian
    for (i in valueBytes.indices.reversed()) {
        val targetIndex = valueBytes.size - 1 - i
        if (targetIndex < 16) {
            bytes[targetIndex] = valueBytes[i]
        }
    }

    return writeFixedBytes(bytes, 16)
}

/**
 * Write a u256 from BigInteger
 */
fun BcsSerializer.writeU256(value: BigInteger): BcsSerializer {
    require(value >= BigInteger.ZERO) { "u256 must be non-negative" }
    require(value < BigInteger.TWO.pow(256)) { "u256 overflow" }

    val bytes = ByteArray(32)
    val valueBytes = value.toByteArray()

    // Convert from big-endian to little-endian
    for (i in valueBytes.indices.reversed()) {
        val targetIndex = valueBytes.size - 1 - i
        if (targetIndex < 32) {
            bytes[targetIndex] = valueBytes[i]
        }
    }

    return writeFixedBytes(bytes, 32)
}

/**
 * Write an i128 from BigInteger
 */
fun BcsSerializer.writeI128(value: BigInteger): BcsSerializer {
    val minValue = BigInteger.ONE.negate().shiftLeft(127)
    val maxValue = BigInteger.ONE.shiftLeft(127).subtract(BigInteger.ONE)
    require(value >= minValue && value <= maxValue) { "i128 out of range" }

    val bytes = ByteArray(16)
    val unsigned = if (value < BigInteger.ZERO) {
        value.add(BigInteger.ONE.shiftLeft(128))
    } else {
        value
    }

    val valueBytes = unsigned.toByteArray()
    for (i in valueBytes.indices.reversed()) {
        val targetIndex = valueBytes.size - 1 - i
        if (targetIndex < 16) {
            bytes[targetIndex] = valueBytes[i]
        }
    }

    return writeFixedBytes(bytes, 16)
}

/**
 * Write an i256 from BigInteger
 */
fun BcsSerializer.writeI256(value: BigInteger): BcsSerializer {
    val minValue = BigInteger.ONE.negate().shiftLeft(255)
    val maxValue = BigInteger.ONE.shiftLeft(255).subtract(BigInteger.ONE)
    require(value >= minValue && value <= maxValue) { "i256 out of range" }

    val bytes = ByteArray(32)
    val unsigned = if (value < BigInteger.ZERO) {
        value.add(BigInteger.ONE.shiftLeft(256))
    } else {
        value
    }

    val valueBytes = unsigned.toByteArray()
    for (i in valueBytes.indices.reversed()) {
        val targetIndex = valueBytes.size - 1 - i
        if (targetIndex < 32) {
            bytes[targetIndex] = valueBytes[i]
        }
    }

    return writeFixedBytes(bytes, 32)
}
