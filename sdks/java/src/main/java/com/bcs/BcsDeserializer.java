package com.bcs;

import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * BCS Deserializer - Manual deserialization API.
 *
 * <p>Provides explicit methods for deserializing each BCS type.
 * Use this for full control over deserialization.</p>
 *
 * <pre>{@code
 * byte[] data = ...;
 * BcsDeserializer des = new BcsDeserializer(data);
 * short value1 = des.readU8();
 * long value2 = des.readU64();
 * String value3 = des.readString();
 * des.checkEnd();
 * }</pre>
 *
 * @implNote Uses a ThreadLocal CharsetDecoder for efficient string validation.
 */
public class BcsDeserializer {

    // Pre-computed constants for signed integer conversion
    private static final BigInteger SIGN_BIT_128 = BigInteger.ONE.shiftLeft(127);
    private static final BigInteger TWO_POW_128 = BigInteger.ONE.shiftLeft(128);
    private static final BigInteger SIGN_BIT_256 = BigInteger.ONE.shiftLeft(255);
    private static final BigInteger TWO_POW_256 = BigInteger.ONE.shiftLeft(256);

    // ThreadLocal CharsetDecoder for efficient string validation (avoids allocation per call)
    private static final ThreadLocal<CharsetDecoder> UTF8_DECODER = ThreadLocal.withInitial(() ->
        StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
    );

    private final byte[] data;
    private int offset = 0;
    private int currentDepth = 0;

    /**
     * Create a new deserializer.
     *
     * @param data the data to deserialize from
     */
    public BcsDeserializer(byte[] data) {
        this.data = data;
    }

    // ==========================================================================
    // BOOLEAN
    // ==========================================================================

    /**
     * Deserialize a boolean value.
     *
     * @return the boolean value
     * @throws BcsError if invalid
     */
    public boolean readBool() {
        ensureBytes(1);
        int byteVal = data[offset++] & 0xFF;
        if (byteVal == 0) {
            return false;
        }
        if (byteVal == 1) {
            return true;
        }
        throw BcsError.invalidBoolean(byteVal);
    }

    // ==========================================================================
    // UNSIGNED INTEGERS
    // ==========================================================================

    /**
     * Deserialize an unsigned 8-bit integer.
     *
     * @return the value (0-255)
     */
    public short readU8() {
        ensureBytes(1);
        return (short) (data[offset++] & 0xFF);
    }

    /**
     * Deserialize an unsigned 16-bit integer (little-endian).
     *
     * @return the value (0-65535)
     */
    public int readU16() {
        ensureBytes(2);
        int value = (data[offset] & 0xFF) | ((data[offset + 1] & 0xFF) << 8);
        offset += 2;
        return value;
    }

    /**
     * Deserialize an unsigned 32-bit integer (little-endian).
     *
     * @return the value (0 to 2^32-1)
     */
    public long readU32() {
        ensureBytes(4);
        long value = (data[offset] & 0xFFL)
                | ((data[offset + 1] & 0xFFL) << 8)
                | ((data[offset + 2] & 0xFFL) << 16)
                | ((data[offset + 3] & 0xFFL) << 24);
        offset += 4;
        return value;
    }

    /**
     * Deserialize an unsigned 64-bit integer (little-endian).
     *
     * @return the value (as long, interpret as unsigned)
     */
    public long readU64() {
        ensureBytes(8);
        // Inline for performance - avoid method call overhead
        long value = (data[offset] & 0xFFL)
                | ((data[offset + 1] & 0xFFL) << 8)
                | ((data[offset + 2] & 0xFFL) << 16)
                | ((data[offset + 3] & 0xFFL) << 24)
                | ((data[offset + 4] & 0xFFL) << 32)
                | ((data[offset + 5] & 0xFFL) << 40)
                | ((data[offset + 6] & 0xFFL) << 48)
                | ((data[offset + 7] & 0xFFL) << 56);
        offset += 8;
        return value;
    }

    /**
     * Deserialize an unsigned 128-bit integer (little-endian).
     *
     * @return the value as BigInteger
     */
    public BigInteger readU128() {
        ensureBytes(16);
        return readBigIntegerLE(16);
    }

    /**
     * Deserialize an unsigned 256-bit integer (little-endian).
     *
     * @return the value as BigInteger
     */
    public BigInteger readU256() {
        ensureBytes(32);
        return readBigIntegerLE(32);
    }

    // ==========================================================================
    // SIGNED INTEGERS
    // ==========================================================================

    /**
     * Deserialize a signed 8-bit integer (two's complement).
     *
     * @return the value (-128 to 127)
     */
    public byte readI8() {
        ensureBytes(1);
        return data[offset++];
    }

    /**
     * Deserialize a signed 16-bit integer (two's complement, little-endian).
     *
     * @return the value (-32768 to 32767)
     */
    public short readI16() {
        int unsigned = readU16();
        return (short) unsigned;
    }

    /**
     * Deserialize a signed 32-bit integer (two's complement, little-endian).
     *
     * @return the value
     */
    public int readI32() {
        long unsigned = readU32();
        return (int) unsigned;
    }

    /**
     * Deserialize a signed 64-bit integer (two's complement, little-endian).
     *
     * @return the value
     */
    public long readI64() {
        return readU64(); // Same bits, Java interprets as signed
    }

    /**
     * Deserialize a signed 128-bit integer (two's complement, little-endian).
     *
     * @return the value as BigInteger
     */
    public BigInteger readI128() {
        BigInteger unsigned = readU128();
        if (unsigned.compareTo(SIGN_BIT_128) >= 0) {
            return unsigned.subtract(TWO_POW_128);
        }
        return unsigned;
    }

    /**
     * Deserialize a signed 256-bit integer (two's complement, little-endian).
     *
     * @return the value as BigInteger
     */
    public BigInteger readI256() {
        BigInteger unsigned = readU256();
        if (unsigned.compareTo(SIGN_BIT_256) >= 0) {
            return unsigned.subtract(TWO_POW_256);
        }
        return unsigned;
    }

    // ==========================================================================
    // ULEB128
    // ==========================================================================

    /**
     * Deserialize a ULEB128-encoded unsigned integer.
     *
     * @return the value (0 to 2^32-1)
     */
    public long readUleb128() {
        Uleb128.DecodeResult result = Uleb128.decode(data, offset);
        offset += result.getBytesConsumed();
        return result.getValue();
    }

    // ==========================================================================
    // BYTES AND STRINGS
    // ==========================================================================

    /**
     * Deserialize a byte array (length-prefixed with ULEB128).
     *
     * @return the bytes
     */
    public byte[] readBytes() {
        long length = readUleb128();
        if (length > BcsSerializer.MAX_SEQUENCE_LENGTH) {
            throw BcsError.exceededMaxLength(length);
        }
        // Defense-in-depth: explicit check before cast
        if (length > Integer.MAX_VALUE) {
            throw BcsError.exceededMaxLength(length);
        }
        return readFixedBytes((int) length);
    }

    /**
     * Deserialize a UTF-8 string (length-prefixed with ULEB128).
     *
     * @return the string
     */
    public String readString() {
        byte[] bytes = readBytes();
        // Use cached ThreadLocal decoder for better performance
        CharsetDecoder decoder = UTF8_DECODER.get();
        decoder.reset(); // Reset state for reuse
        try {
            return decoder.decode(ByteBuffer.wrap(bytes)).toString();
        } catch (CharacterCodingException e) {
            throw BcsError.invalidUtf8(e.getMessage());
        }
    }

    /**
     * Deserialize fixed-length bytes (no length prefix).
     *
     * @param length the number of bytes to read
     * @return the bytes
     */
    public byte[] readFixedBytes(int length) {
        ensureBytes(length);
        byte[] result = Arrays.copyOfRange(data, offset, offset + length);
        offset += length;
        return result;
    }

    // ==========================================================================
    // OPTION
    // ==========================================================================

    /**
     * Deserialize an optional value.
     *
     * @param deserializer function to deserialize the inner value
     * @param <T> the type of the optional value
     * @return the value or null if None
     */
    public <T> T readOption(Function<BcsDeserializer, T> deserializer) {
        ensureBytes(1);
        int tag = data[offset++] & 0xFF;
        if (tag == 0) {
            return null;
        }
        if (tag == 1) {
            return deserializer.apply(this);
        }
        throw BcsError.invalidOption(tag);
    }

    // ==========================================================================
    // VECTOR
    // ==========================================================================

    /**
     * Deserialize a vector of values.
     *
     * @param deserializer function to deserialize each element
     * @param <T> the type of vector elements
     * @return the list of values
     */
    public <T> List<T> readVector(Function<BcsDeserializer, T> deserializer) {
        long length = readUleb128();
        // Check both MAX_SEQUENCE_LENGTH and Integer.MAX_VALUE for defense-in-depth
        if (length > BcsSerializer.MAX_SEQUENCE_LENGTH || length > Integer.MAX_VALUE) {
            throw BcsError.exceededMaxLength(length);
        }
        int len = (int) length;
        List<T> result = new ArrayList<>(len);
        for (int i = 0; i < len; i++) {
            result.add(deserializer.apply(this));
        }
        return result;
    }

    // ==========================================================================
    // ENUM
    // ==========================================================================

    /**
     * Enter an enum container and read its variant index (ULEB128).
     *
     * @return the variant index
     * @throws BcsError if the variant index exceeds Integer.MAX_VALUE
     */
    public int enterEnum() {
        enterContainer("enum");
        long index = readUleb128();
        if (index > Integer.MAX_VALUE) {
            throw BcsError.valueOutOfRange("variant index", index);
        }
        return (int) index;
    }

    /**
     * Leave the current enum container.
     */
    public void leaveEnum() {
        leaveContainer();
    }

    /**
     * Read an enum variant index (ULEB128).
     *
     * @return the variant index
     */
    public int readVariantIndex() {
        return enterEnum();
    }

    // ==========================================================================
    // MAP
    // ==========================================================================

    /**
     * Deserialize a map (verifying sorted keys).
     *
     * @param keyDeserializer function to deserialize keys
     * @param valueDeserializer function to deserialize values
     * @param <K> the key type
     * @param <V> the value type
     * @return the map
     */
    public <K, V> Map<K, V> readMap(
            Function<BcsDeserializer, K> keyDeserializer, Function<BcsDeserializer, V> valueDeserializer) {

        long length = readUleb128();
        if (length > BcsSerializer.MAX_SEQUENCE_LENGTH) {
            throw BcsError.exceededMaxLength(length);
        }
        // Defense-in-depth: explicit check before cast
        if (length > Integer.MAX_VALUE) {
            throw BcsError.exceededMaxLength(length);
        }
        int len = (int) length;

        // Pre-allocate with capacity hint for better performance
        Map<K, V> result = new LinkedHashMap<>(len);
        byte[] prevKeyBytes = null;

        for (int i = 0; i < len; i++) {
            // Record position before reading key
            int keyStart = offset;
            K key = keyDeserializer.apply(this);
            int keyEnd = offset;

            // Verify key order using view comparison (zero-copy)
            if (prevKeyBytes != null) {
                int cmp = compareBytesRange(prevKeyBytes, 0, prevKeyBytes.length, 
                                           data, keyStart, keyEnd - keyStart);
                if (cmp == 0) {
                    throw BcsError.nonCanonicalMap("duplicate key");
                }
                if (cmp > 0) {
                    throw BcsError.nonCanonicalMap("keys not sorted");
                }
            }
            // Only copy for storing as previous key
            prevKeyBytes = Arrays.copyOfRange(data, keyStart, keyEnd);

            V value = valueDeserializer.apply(this);
            result.put(key, value);
        }

        return result;
    }

    // ==========================================================================
    // UTILITY
    // ==========================================================================

    /**
     * Check that all input has been consumed.
     *
     * @throws BcsError if there is remaining input
     */
    public void checkEnd() {
        if (offset < data.length) {
            throw BcsError.remainingInput(data.length - offset);
        }
    }

    /**
     * Get the number of remaining bytes.
     *
     * @return the number of remaining bytes
     */
    public int remaining() {
        return data.length - offset;
    }

    /**
     * Get the current offset.
     *
     * @return the current position
     */
    public int position() {
        return offset;
    }

    // ==========================================================================
    // CONTAINER DEPTH
    // ==========================================================================

    /**
     * Enter a struct container for depth tracking.
     */
    public void enterStruct() {
        enterStruct("");
    }

    /**
     * Enter a struct container for depth tracking.
     *
     * @param name optional struct name for error messages
     */
    public void enterStruct(String name) {
        enterContainer(name);
    }

    /**
     * Leave the current struct container.
     */
    public void leaveStruct() {
        leaveContainer();
    }

    // ==========================================================================
    // PRIVATE HELPERS
    // ==========================================================================

    private void ensureBytes(int count) {
        if (offset + count > data.length) {
            throw BcsError.unexpectedEof(count, data.length - offset);
        }
    }

    private void enterContainer(String container) {
        if (currentDepth >= BcsSerializer.MAX_CONTAINER_DEPTH) {
            throw BcsError.exceededContainerDepth(container);
        }
        currentDepth++;
    }

    private void leaveContainer() {
        if (currentDepth > 0) {
            currentDepth--;
        }
    }

    private BigInteger readBigIntegerLE(int byteLength) {
        // Convert little-endian bytes to BigInteger (big-endian, positive)
        // Allocate one extra byte at the start for sign (ensure positive)
        byte[] bigEndian = new byte[byteLength + 1];
        // bigEndian[0] = 0 by default, ensures positive BigInteger

        // Reverse bytes from little-endian to big-endian
        int srcEnd = offset + byteLength - 1;
        for (int i = 1; i <= byteLength; i++) {
            bigEndian[i] = data[srcEnd - i + 1];
        }
        offset += byteLength;
        return new BigInteger(bigEndian);
    }

    /**
     * Compare two byte arrays as unsigned bytes (lexicographic).
     */
    private static int compareBytes(byte[] a, byte[] b) {
        return Arrays.compareUnsigned(a, b);
    }

    /**
     * Compare a byte array with a range in another array (zero-copy comparison).
     */
    private static int compareBytesRange(byte[] a, int aOffset, int aLen, 
                                         byte[] b, int bOffset, int bLen) {
        int minLen = Math.min(aLen, bLen);
        for (int i = 0; i < minLen; i++) {
            int cmp = (a[aOffset + i] & 0xFF) - (b[bOffset + i] & 0xFF);
            if (cmp != 0) {
                return cmp;
            }
        }
        return aLen - bLen;
    }
}
