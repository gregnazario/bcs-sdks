/**
 * BCS Serializer - Manual serialization API
 */
package com.bcs

import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets

/**
 * BCS Serializer for manual serialization
 */
class BcsSerializer {
    private val buffer = ByteArrayOutputStream()
    private var depth = 0

    // =========================================================================
    // Boolean
    // =========================================================================

    fun writeBool(value: Boolean): BcsSerializer {
        buffer.write(if (value) 1 else 0)
        return this
    }

    // =========================================================================
    // Unsigned Integers
    // =========================================================================

    fun writeU8(value: Int): BcsSerializer {
        require(value in 0..255) { "u8 value out of range: $value" }
        buffer.write(value)
        return this
    }

    fun writeU16(value: Int): BcsSerializer {
        require(value in 0..65535) { "u16 value out of range: $value" }
        buffer.write(value and 0xFF)
        buffer.write((value shr 8) and 0xFF)
        return this
    }

    fun writeU32(value: Long): BcsSerializer {
        require(value in 0..0xFFFFFFFFL) { "u32 value out of range: $value" }
        for (i in 0 until 4) {
            buffer.write(((value shr (i * 8)) and 0xFF).toInt())
        }
        return this
    }

    fun writeU64(value: Long): BcsSerializer {
        for (i in 0 until 8) {
            buffer.write(((value shr (i * 8)) and 0xFF).toInt())
        }
        return this
    }

    // =========================================================================
    // Signed Integers
    // =========================================================================

    fun writeI8(value: Int): BcsSerializer {
        require(value in -128..127) { "i8 value out of range: $value" }
        buffer.write(value and 0xFF)
        return this
    }

    fun writeI16(value: Int): BcsSerializer {
        require(value in -32768..32767) { "i16 value out of range: $value" }
        val unsigned = value and 0xFFFF
        buffer.write(unsigned and 0xFF)
        buffer.write((unsigned shr 8) and 0xFF)
        return this
    }

    fun writeI32(value: Int): BcsSerializer {
        val unsigned = value.toLong() and 0xFFFFFFFFL
        for (i in 0 until 4) {
            buffer.write(((unsigned shr (i * 8)) and 0xFF).toInt())
        }
        return this
    }

    fun writeI64(value: Long): BcsSerializer {
        for (i in 0 until 8) {
            buffer.write(((value shr (i * 8)) and 0xFF).toInt())
        }
        return this
    }

    // =========================================================================
    // ULEB128
    // =========================================================================

    fun writeUleb128(value: Int): BcsSerializer {
        buffer.write(Uleb128.encode(value))
        return this
    }

    fun writeUleb128(value: Long): BcsSerializer {
        buffer.write(Uleb128.encode(value))
        return this
    }

    // =========================================================================
    // Bytes and Strings
    // =========================================================================

    fun writeFixedBytes(data: ByteArray, length: Int): BcsSerializer {
        require(data.size == length) { "Expected $length bytes, got ${data.size}" }
        buffer.write(data)
        return this
    }

    fun writeBytes(data: ByteArray): BcsSerializer {
        checkSequenceLength(data.size)
        writeUleb128(data.size)
        buffer.write(data)
        return this
    }

    fun writeString(value: String): BcsSerializer {
        val bytes = value.toByteArray(StandardCharsets.UTF_8)
        checkSequenceLength(bytes.size)
        writeUleb128(bytes.size)
        buffer.write(bytes)
        return this
    }

    // =========================================================================
    // Container Depth
    // =========================================================================

    fun enterStruct(name: String = ""): BcsSerializer {
        enterContainer(name)
        return this
    }

    fun leaveStruct(): BcsSerializer {
        leaveContainer()
        return this
    }

    fun enterEnum(index: Int): BcsSerializer {
        enterContainer("enum")
        writeUleb128(index)
        return this
    }

    fun leaveEnum(): BcsSerializer {
        leaveContainer()
        return this
    }

    fun writeVariantIndex(index: Int): BcsSerializer = enterEnum(index)

    // =========================================================================
    // Output
    // =========================================================================

    fun toBytes(): ByteArray = buffer.toByteArray()

    val size: Int get() = buffer.size()

    fun reset() {
        buffer.reset()
        depth = 0
    }

    // =========================================================================
    // Private Helpers
    // =========================================================================

    private fun checkSequenceLength(length: Int) {
        if (length > BcsConstants.MAX_SEQUENCE_LENGTH) {
            throw BcsError.exceededMaxLength(length)
        }
    }

    private fun enterContainer(container: String) {
        if (depth >= BcsConstants.MAX_CONTAINER_DEPTH) {
            throw BcsError.exceededContainerDepth(container)
        }
        depth++
    }

    private fun leaveContainer() {
        if (depth > 0) depth--
    }
}
