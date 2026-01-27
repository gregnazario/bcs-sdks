/**
 * BCS Kotlin SDK - Idiomatic Kotlin bindings for Binary Canonical Serialization
 *
 * This package provides Kotlin-specific extensions and DSL for the Java BCS implementation.
 */
package com.bcs

import java.math.BigInteger

/**
 * BCS constants
 */
object BcsConstants {
    /** Maximum length for variable-length sequences (2^31 - 1) */
    const val MAX_SEQUENCE_LENGTH: Int = Int.MAX_VALUE

    /** Maximum container depth for nested structures */
    const val MAX_CONTAINER_DEPTH: Int = 500
}

/**
 * Convenience function to serialize using a builder DSL
 *
 * @param block the serialization block
 * @return the serialized bytes
 */
inline fun bcsSerialize(block: BcsSerializer.() -> Unit): ByteArray {
    return BcsSerializer().apply(block).toBytes()
}

/**
 * Convenience function to deserialize using a builder DSL
 *
 * @param data the data to deserialize
 * @param block the deserialization block
 * @return the result of the block
 */
inline fun <T> bcsDeserialize(data: ByteArray, block: BcsDeserializer.() -> T): T {
    return BcsDeserializer(data).run {
        val result = block()
        checkEnd()
        result
    }
}

// Lookup table for hex encoding (avoids string formatting overhead)
private val HEX_CHARS = "0123456789abcdef".toCharArray()
private val HEX_DECODE = IntArray(128) { -1 }.apply {
    for (i in '0'.code..'9'.code) this[i] = i - '0'.code
    for (i in 'a'.code..'f'.code) this[i] = i - 'a'.code + 10
    for (i in 'A'.code..'F'.code) this[i] = i - 'A'.code + 10
}

/**
 * Convert a hex string to bytes (optimized with lookup table)
 */
fun String.hexToBytes(): ByteArray {
    require(length % 2 == 0) { "Hex string must have even length" }
    val result = ByteArray(length / 2)
    for (i in result.indices) {
        val high = HEX_DECODE[this[i * 2].code]
        val low = HEX_DECODE[this[i * 2 + 1].code]
        require(high >= 0 && low >= 0) { "Invalid hex character" }
        result[i] = ((high shl 4) or low).toByte()
    }
    return result
}

/**
 * Convert bytes to hex string (optimized with lookup table)
 */
fun ByteArray.toHex(): String {
    val chars = CharArray(size * 2)
    for (i in indices) {
        val b = this[i].toInt() and 0xFF
        chars[i * 2] = HEX_CHARS[b shr 4]
        chars[i * 2 + 1] = HEX_CHARS[b and 0x0F]
    }
    return String(chars)
}

/**
 * Convert bytes to hex string into a pre-allocated StringBuilder
 */
fun ByteArray.appendHexTo(sb: StringBuilder) {
    for (b in this) {
        val v = b.toInt() and 0xFF
        sb.append(HEX_CHARS[v shr 4])
        sb.append(HEX_CHARS[v and 0x0F])
    }
}
