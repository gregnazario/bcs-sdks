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

/**
 * Convert a hex string to bytes
 */
fun String.hexToBytes(): ByteArray {
    require(length % 2 == 0) { "Hex string must have even length" }
    return ByteArray(length / 2) { i ->
        substring(i * 2, i * 2 + 2).toInt(16).toByte()
    }
}

/**
 * Convert bytes to hex string
 */
fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
