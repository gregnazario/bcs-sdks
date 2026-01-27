/**
 * BCS Deserializer - Manual deserialization API
 */
package com.bcs

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets

/**
 * BCS Deserializer for manual deserialization
 * 
 * Optimized for performance with:
 * - Direct array access for integer reads
 * - Fast path for common ULEB128 values
 * - Minimal object allocations
 */
class BcsDeserializer(private val data: ByteArray) {
    var offset: Int = 0
        private set
    private var depth = 0
    
    /** Data length cached for faster access */
    private val dataLen = data.size

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
    // Unsigned Integers (optimized with direct array access)
    // =========================================================================

    fun readU8(): Int {
        if (offset >= dataLen) throw BcsError.unexpectedEof()
        return data[offset++].toInt() and 0xFF
    }

    fun readU16(): Int {
        if (offset + 2 > dataLen) throw BcsError.unexpectedEof()
        val result = (data[offset].toInt() and 0xFF) or
                ((data[offset + 1].toInt() and 0xFF) shl 8)
        offset += 2
        return result
    }

    fun readU32(): Long {
        if (offset + 4 > dataLen) throw BcsError.unexpectedEof()
        // Unrolled loop for better performance
        val result = (data[offset].toLong() and 0xFF) or
                ((data[offset + 1].toLong() and 0xFF) shl 8) or
                ((data[offset + 2].toLong() and 0xFF) shl 16) or
                ((data[offset + 3].toLong() and 0xFF) shl 24)
        offset += 4
        return result
    }

    fun readU64(): Long {
        if (offset + 8 > dataLen) throw BcsError.unexpectedEof()
        // Unrolled loop for better performance
        val result = (data[offset].toLong() and 0xFF) or
                ((data[offset + 1].toLong() and 0xFF) shl 8) or
                ((data[offset + 2].toLong() and 0xFF) shl 16) or
                ((data[offset + 3].toLong() and 0xFF) shl 24) or
                ((data[offset + 4].toLong() and 0xFF) shl 32) or
                ((data[offset + 5].toLong() and 0xFF) shl 40) or
                ((data[offset + 6].toLong() and 0xFF) shl 48) or
                ((data[offset + 7].toLong() and 0xFF) shl 56)
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

    fun readI32(): Int = readU32().toInt()

    fun readI64(): Long = readU64()

    // =========================================================================
    // ULEB128 (with fast path for single-byte values)
    // =========================================================================

    fun readUleb128(): Long {
        // Fast path for single-byte values (0-127)
        if (offset >= dataLen) throw BcsError.unexpectedEof()
        val first = data[offset].toInt() and 0xFF
        if (first < 0x80) {
            offset++
            return first.toLong()
        }
        // Multi-byte decoding
        val (value, bytesRead) = Uleb128.decode(data, offset)
        offset += bytesRead
        return value
    }

    // =========================================================================
    // Bytes and Strings
    // =========================================================================

    fun readFixedBytes(length: Int): ByteArray {
        if (offset + length > dataLen) throw BcsError.unexpectedEof()
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
    // Batch Operations (optimized for vectors of primitives)
    // =========================================================================
    
    /**
     * Read a vector of u8 values efficiently
     */
    fun readU8Vector(): ByteArray {
        val length = readUleb128().toInt()
        checkSequenceLength(length)
        return readFixedBytes(length)
    }
    
    /**
     * Read a vector of u16 values efficiently
     */
    fun readU16Vector(): ShortArray {
        val length = readUleb128().toInt()
        checkSequenceLength(length)
        val byteLen = length * 2
        if (offset + byteLen > dataLen) throw BcsError.unexpectedEof()
        
        val result = ShortArray(length)
        val buf = ByteBuffer.wrap(data, offset, byteLen).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until length) result[i] = buf.short
        offset += byteLen
        return result
    }
    
    /**
     * Read a vector of u32 values efficiently
     */
    fun readU32Vector(): IntArray {
        val length = readUleb128().toInt()
        checkSequenceLength(length)
        val byteLen = length * 4
        if (offset + byteLen > dataLen) throw BcsError.unexpectedEof()
        
        val result = IntArray(length)
        val buf = ByteBuffer.wrap(data, offset, byteLen).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until length) result[i] = buf.int
        offset += byteLen
        return result
    }
    
    /**
     * Read a vector of u64 values efficiently
     */
    fun readU64Vector(): LongArray {
        val length = readUleb128().toInt()
        checkSequenceLength(length)
        val byteLen = length * 8
        if (offset + byteLen > dataLen) throw BcsError.unexpectedEof()
        
        val result = LongArray(length)
        val buf = ByteBuffer.wrap(data, offset, byteLen).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until length) result[i] = buf.long
        offset += byteLen
        return result
    }
    
    /**
     * Peek at next byte without consuming it
     */
    fun peek(): Int {
        if (offset >= dataLen) throw BcsError.unexpectedEof()
        return data[offset].toInt() and 0xFF
    }
    
    /**
     * Skip n bytes
     */
    fun skip(n: Int) {
        if (offset + n > dataLen) throw BcsError.unexpectedEof()
        offset += n
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
