/**
 * ULEB128 encoding/decoding utilities
 */
package com.bcs

/**
 * ULEB128 utilities - optimized for performance
 */
object Uleb128 {
    /** Maximum value that can be encoded as ULEB128 in BCS (u32 max) */
    const val MAX_VALUE: Long = 0xFFFFFFFFL

    /** Maximum number of bytes in a ULEB128-encoded u32 */
    const val MAX_BYTES: Int = 5

    // Pre-allocated buffer for encoding (thread-local for thread safety)
    private val encodeBuffer = ThreadLocal.withInitial { ByteArray(MAX_BYTES) }

    /**
     * Encode a 32-bit unsigned integer as ULEB128
     * Optimized to avoid list allocations
     */
    fun encode(value: Long): ByteArray {
        require(value >= 0 && value <= MAX_VALUE) { "Value out of range for ULEB128" }

        // Fast path for single-byte values
        if (value < 0x80) {
            return byteArrayOf(value.toByte())
        }

        val buffer = encodeBuffer.get()
        var v = value
        var i = 0

        do {
            var byte = (v and 0x7F).toInt()
            v = v shr 7
            if (v != 0L) {
                byte = byte or 0x80
            }
            buffer[i++] = byte.toByte()
        } while (v != 0L)

        return buffer.copyOf(i)
    }

    /**
     * Encode a 32-bit unsigned integer as ULEB128
     */
    fun encode(value: Int): ByteArray = encode(value.toLong() and 0xFFFFFFFFL)

    /**
     * Encode directly into a destination array at given offset
     * Returns number of bytes written
     */
    fun encodeInto(value: Long, dest: ByteArray, destOffset: Int): Int {
        require(value >= 0 && value <= MAX_VALUE) { "Value out of range for ULEB128" }

        var v = value
        var i = 0

        do {
            var byte = (v and 0x7F).toInt()
            v = v shr 7
            if (v != 0L) {
                byte = byte or 0x80
            }
            dest[destOffset + i++] = byte.toByte()
        } while (v != 0L)

        return i
    }

    /**
     * Decode a ULEB128-encoded value from bytes
     *
     * @return Pair of (decoded value, bytes consumed)
     */
    fun decode(data: ByteArray, offset: Int = 0): Pair<Long, Int> {
        val dataLen = data.size
        var value = 0L
        var shift = 0
        var bytesRead = 0

        for (i in 0 until MAX_BYTES) {
            val idx = offset + i
            if (idx >= dataLen) {
                throw BcsError.unexpectedEof()
            }

            val byte = data[idx].toInt() and 0xFF
            val digit = byte and 0x7F

            value = value or (digit.toLong() shl shift)
            bytesRead = i + 1

            // Check if this is the last byte (high bit not set)
            if ((byte and 0x80) == 0) {
                // Check for non-canonical encoding (trailing zeros)
                if (shift > 0 && digit == 0) {
                    throw BcsError.nonCanonicalUleb128()
                }

                // Check for overflow
                if (value > MAX_VALUE) {
                    throw BcsError.uleb128Overflow()
                }

                return Pair(value, bytesRead)
            }

            shift += 7
        }

        // If we've read MAX_BYTES and still have continuation bit, overflow
        throw BcsError.uleb128Overflow()
    }

    /**
     * Calculate the encoded size of a value
     */
    fun encodedSize(value: Long): Int {
        if (value < 0x80) return 1
        if (value < 0x4000) return 2
        if (value < 0x200000) return 3
        if (value < 0x10000000) return 4
        return 5
    }
}
