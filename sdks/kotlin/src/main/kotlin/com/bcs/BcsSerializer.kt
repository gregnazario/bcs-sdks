/**
 * BCS Serializer - Manual serialization API
 */
package com.bcs

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets

/**
 * BCS Serializer for manual serialization
 * 
 * Optimized for performance with:
 * - Pre-allocated buffers for integer writes
 * - Fast path for common ULEB128 values
 * - Direct byte array operations where possible
 */
class BcsSerializer private constructor(initialCapacity: Int) {
    private val buffer = ByteArrayOutputStream(initialCapacity)
    private var depth = 0
    
    // Pre-allocated buffers for integer serialization (avoids allocations)
    private val intBuffer = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN)

    constructor() : this(DEFAULT_CAPACITY)

    companion object {
        /** Default initial buffer capacity */
        const val DEFAULT_CAPACITY = 256
        
        /** Create serializer with custom initial capacity */
        @JvmStatic
        fun withCapacity(capacity: Int): BcsSerializer = BcsSerializer(capacity)
    }

    // =========================================================================
    // Boolean
    // =========================================================================

    fun writeBool(value: Boolean): BcsSerializer {
        buffer.write(if (value) 1 else 0)
        return this
    }

    // =========================================================================
    // Unsigned Integers (optimized with ByteBuffer)
    // =========================================================================

    fun writeU8(value: Int): BcsSerializer {
        require(value in 0..255) { "u8 value out of range: $value" }
        buffer.write(value)
        return this
    }

    fun writeU16(value: Int): BcsSerializer {
        require(value in 0..65535) { "u16 value out of range: $value" }
        intBuffer.clear()
        intBuffer.putShort(value.toShort())
        buffer.write(intBuffer.array(), 0, 2)
        return this
    }

    fun writeU32(value: Long): BcsSerializer {
        require(value in 0..0xFFFFFFFFL) { "u32 value out of range: $value" }
        intBuffer.clear()
        intBuffer.putInt(value.toInt())
        buffer.write(intBuffer.array(), 0, 4)
        return this
    }

    fun writeU64(value: Long): BcsSerializer {
        intBuffer.clear()
        intBuffer.putLong(value)
        buffer.write(intBuffer.array(), 0, 8)
        return this
    }

    // =========================================================================
    // Signed Integers (optimized with ByteBuffer)
    // =========================================================================

    fun writeI8(value: Int): BcsSerializer {
        require(value in -128..127) { "i8 value out of range: $value" }
        buffer.write(value and 0xFF)
        return this
    }

    fun writeI16(value: Int): BcsSerializer {
        require(value in -32768..32767) { "i16 value out of range: $value" }
        intBuffer.clear()
        intBuffer.putShort(value.toShort())
        buffer.write(intBuffer.array(), 0, 2)
        return this
    }

    fun writeI32(value: Int): BcsSerializer {
        intBuffer.clear()
        intBuffer.putInt(value)
        buffer.write(intBuffer.array(), 0, 4)
        return this
    }

    fun writeI64(value: Long): BcsSerializer {
        intBuffer.clear()
        intBuffer.putLong(value)
        buffer.write(intBuffer.array(), 0, 8)
        return this
    }

    // =========================================================================
    // ULEB128 (with fast path for common small values)
    // =========================================================================

    fun writeUleb128(value: Int): BcsSerializer {
        // Fast path for single-byte values (0-127)
        if (value >= 0 && value < 0x80) {
            buffer.write(value)
            return this
        }
        buffer.write(Uleb128.encode(value))
        return this
    }

    fun writeUleb128(value: Long): BcsSerializer {
        // Fast path for single-byte values (0-127)
        if (value >= 0 && value < 0x80) {
            buffer.write(value.toInt())
            return this
        }
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
    
    fun writeFixedBytes(data: ByteArray): BcsSerializer {
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
    // Batch Operations (optimized for vectors of primitives)
    // =========================================================================
    
    /**
     * Write a vector of u8 values efficiently (writes length then raw bytes)
     */
    fun writeU8Vector(values: ByteArray): BcsSerializer {
        checkSequenceLength(values.size)
        writeUleb128(values.size)
        buffer.write(values)
        return this
    }
    
    /**
     * Write a vector of u16 values efficiently
     */
    fun writeU16Vector(values: ShortArray): BcsSerializer {
        checkSequenceLength(values.size)
        writeUleb128(values.size)
        // Write directly without intermediate buffer allocation
        for (v in values) {
            buffer.write(v.toInt() and 0xFF)
            buffer.write((v.toInt() shr 8) and 0xFF)
        }
        return this
    }
    
    /**
     * Write a vector of u32 values efficiently
     */
    fun writeU32Vector(values: IntArray): BcsSerializer {
        checkSequenceLength(values.size)
        writeUleb128(values.size)
        // Write directly without intermediate buffer allocation
        for (v in values) {
            buffer.write(v and 0xFF)
            buffer.write((v shr 8) and 0xFF)
            buffer.write((v shr 16) and 0xFF)
            buffer.write((v shr 24) and 0xFF)
        }
        return this
    }
    
    /**
     * Write a vector of u64 values efficiently
     */
    fun writeU64Vector(values: LongArray): BcsSerializer {
        checkSequenceLength(values.size)
        writeUleb128(values.size)
        // Write directly without intermediate buffer allocation
        for (v in values) {
            buffer.write((v and 0xFF).toInt())
            buffer.write(((v shr 8) and 0xFF).toInt())
            buffer.write(((v shr 16) and 0xFF).toInt())
            buffer.write(((v shr 24) and 0xFF).toInt())
            buffer.write(((v shr 32) and 0xFF).toInt())
            buffer.write(((v shr 40) and 0xFF).toInt())
            buffer.write(((v shr 48) and 0xFF).toInt())
            buffer.write(((v shr 56) and 0xFF).toInt())
        }
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
