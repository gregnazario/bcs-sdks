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
 */
public class BcsDeserializer {

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
        return readLittleEndian(8);
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
        BigInteger signBit = BigInteger.ONE.shiftLeft(127);
        if (unsigned.compareTo(signBit) >= 0) {
            return unsigned.subtract(BigInteger.ONE.shiftLeft(128));
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
        BigInteger signBit = BigInteger.ONE.shiftLeft(255);
        if (unsigned.compareTo(signBit) >= 0) {
            return unsigned.subtract(BigInteger.ONE.shiftLeft(256));
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
        return readFixedBytes((int) length);
    }

    /**
     * Deserialize a UTF-8 string (length-prefixed with ULEB128).
     *
     * @return the string
     */
    public String readString() {
        byte[] bytes = readBytes();
        CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT);
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
        if (length > BcsSerializer.MAX_SEQUENCE_LENGTH) {
            throw BcsError.exceededMaxLength(length);
        }
        List<T> result = new ArrayList<>((int) length);
        for (int i = 0; i < length; i++) {
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
     */
    public int enterEnum() {
        enterContainer("enum");
        return (int) readUleb128();
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

        Map<K, V> result = new LinkedHashMap<>();
        byte[] prevKeyBytes = null;

        for (int i = 0; i < length; i++) {
            // Record position before reading key
            int keyStart = offset;
            K key = keyDeserializer.apply(this);
            int keyEnd = offset;
            byte[] keyBytes = Arrays.copyOfRange(data, keyStart, keyEnd);

            // Verify key order
            if (prevKeyBytes != null) {
                int cmp = compareBytes(prevKeyBytes, keyBytes);
                if (cmp == 0) {
                    throw BcsError.nonCanonicalMap("duplicate key");
                }
                if (cmp > 0) {
                    throw BcsError.nonCanonicalMap("keys not sorted");
                }
            }
            prevKeyBytes = keyBytes;

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

    private long readLittleEndian(int byteLength) {
        long value = 0;
        for (int i = 0; i < byteLength; i++) {
            value |= ((long) (data[offset + i] & 0xFF)) << (i * 8);
        }
        offset += byteLength;
        return value;
    }

    private BigInteger readBigIntegerLE(int byteLength) {
        // Read as little-endian and convert to BigInteger
        byte[] bigEndian = new byte[byteLength + 1]; // Extra byte for sign
        bigEndian[0] = 0; // Ensure positive
        for (int i = 0; i < byteLength; i++) {
            bigEndian[byteLength - i] = data[offset + i];
        }
        offset += byteLength;
        return new BigInteger(bigEndian);
    }

    private static int compareBytes(byte[] a, byte[] b) {
        int minLen = Math.min(a.length, b.length);
        for (int i = 0; i < minLen; i++) {
            int cmp = (a[i] & 0xFF) - (b[i] & 0xFF);
            if (cmp != 0) {
                return cmp;
            }
        }
        return a.length - b.length;
    }
}
