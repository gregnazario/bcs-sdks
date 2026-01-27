/**
 * BCS Deserializer - Manual deserialization API
 */
package com.bcs

import java.nio.charset.StandardCharsets

/**
 * BCS Deserializer for manual deserialization
 */
class BcsDeserializer(private val data: ByteArray) {
    var offset: Int = 0
        private set
    private var depth = 0

    // =========================================================================
    // Boolean
    // =========================================================================

    fun readBool(): Boolean {
        val byte = readU8()
        return when (byte) {
            0 -> false
            1 -> true
            else -> throw BcsError.invalidBoolean(byte)
        }
    }

    // =========================================================================
    // Unsigned Integers
    // =========================================================================

    fun readU8(): Int {
        checkRemaining(1)
        return data[offset++].toInt() and 0xFF
    }

    fun readU16(): Int {
        checkRemaining(2)
        val result = (data[offset].toInt() and 0xFF) or
                ((data[offset + 1].toInt() and 0xFF) shl 8)
        offset += 2
        return result
    }

    fun readU32(): Long {
        checkRemaining(4)
        var result = 0L
        for (i in 0 until 4) {
            result = result or ((data[offset + i].toLong() and 0xFF) shl (i * 8))
        }
        offset += 4
        return result
    }

    fun readU64(): Long {
        checkRemaining(8)
        var result = 0L
        for (i in 0 until 8) {
            result = result or ((data[offset + i].toLong() and 0xFF) shl (i * 8))
        }
        offset += 8
        return result
    }

    // =========================================================================
    // Signed Integers
    // =========================================================================

    fun readI8(): Int {
        val value = readU8()
        return if (value >= 0x80) value - 0x100 else value
    }

    fun readI16(): Int {
        val value = readU16()
        return if (value >= 0x8000) value - 0x10000 else value
    }

    fun readI32(): Int {
        val value = readU32()
        return value.toInt()
    }

    fun readI64(): Long = readU64()

    // =========================================================================
    // ULEB128
    // =========================================================================

    fun readUleb128(): Long {
        val (value, bytesRead) = Uleb128.decode(data, offset)
        offset += bytesRead
        return value
    }

    // =========================================================================
    // Bytes and Strings
    // =========================================================================

    fun readFixedBytes(length: Int): ByteArray {
        checkRemaining(length)
        val result = data.copyOfRange(offset, offset + length)
        offset += length
        return result
    }

    fun readBytes(): ByteArray {
        val length = readUleb128().toInt()
        checkSequenceLength(length)
        return readFixedBytes(length)
    }

    fun readString(): String {
        val bytes = readBytes()
        return try {
            String(bytes, StandardCharsets.UTF_8).also { str ->
                // Verify it's valid UTF-8 by checking if encoding back gives same bytes
                if (!str.toByteArray(StandardCharsets.UTF_8).contentEquals(bytes)) {
                    throw BcsError.invalidUtf8()
                }
            }
        } catch (e: Exception) {
            if (e is BcsError) throw e
            throw BcsError.invalidUtf8(e.message)
        }
    }

    // =========================================================================
    // Container Depth
    // =========================================================================

    fun enterStruct(name: String = ""): BcsDeserializer {
        enterContainer(name)
        return this
    }

    fun leaveStruct(): BcsDeserializer {
        leaveContainer()
        return this
    }

    fun enterEnum(): Int {
        enterContainer("enum")
        return readUleb128().toInt()
    }

    fun leaveEnum(): BcsDeserializer {
        leaveContainer()
        return this
    }

    fun readVariantIndex(): Int = enterEnum()

    // =========================================================================
    // State
    // =========================================================================

    fun checkEnd() {
        if (offset < data.size) {
            throw BcsError.remainingInput(data.size - offset)
        }
    }

    fun remaining(): Int = data.size - offset

    val hasRemaining: Boolean get() = offset < data.size

    // =========================================================================
    // Private Helpers
    // =========================================================================

    private fun checkRemaining(needed: Int) {
        if (offset + needed > data.size) {
            throw BcsError.unexpectedEof()
        }
    }

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
