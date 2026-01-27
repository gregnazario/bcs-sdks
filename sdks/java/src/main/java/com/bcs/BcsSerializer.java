package com.bcs;

import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.function.BiConsumer;

/**
 * BCS Serializer - Manual serialization API.
 *
 * <p>Provides explicit methods for serializing each BCS type.
 * Use this for full control over serialization.</p>
 *
 * <pre>{@code
 * BcsSerializer ser = new BcsSerializer();
 * ser.writeU8((short) 1);
 * ser.writeU64(100L);
 * ser.writeString("hello");
 * byte[] bytes = ser.toBytes();
 * }</pre>
 */
public class BcsSerializer {

    /** Maximum allowed sequence length. */
    public static final int MAX_SEQUENCE_LENGTH = Integer.MAX_VALUE; // 2^31 - 1

    /** Maximum allowed container nesting depth. */
    public static final int MAX_CONTAINER_DEPTH = 500;

    /** Default initial buffer capacity. */
    private static final int DEFAULT_CAPACITY = 256;

    // Integer bounds (computed once)
    private static final BigInteger U128_MAX = BigInteger.ONE.shiftLeft(128).subtract(BigInteger.ONE);
    private static final BigInteger U256_MAX = BigInteger.ONE.shiftLeft(256).subtract(BigInteger.ONE);
    private static final BigInteger I128_MIN = BigInteger.ONE.shiftLeft(127).negate();
    private static final BigInteger I128_MAX = BigInteger.ONE.shiftLeft(127).subtract(BigInteger.ONE);
    private static final BigInteger I256_MIN = BigInteger.ONE.shiftLeft(255).negate();
    private static final BigInteger I256_MAX = BigInteger.ONE.shiftLeft(255).subtract(BigInteger.ONE);
    private static final BigInteger TWO_POW_128 = BigInteger.ONE.shiftLeft(128);
    private static final BigInteger TWO_POW_256 = BigInteger.ONE.shiftLeft(256);

    // Direct byte buffer for better performance than ByteArrayOutputStream
    private byte[] buffer;
    private int size;
    private int currentDepth = 0;

    /** Create a new serializer with default capacity. */
    public BcsSerializer() {
        this(DEFAULT_CAPACITY);
    }

    /**
     * Create a new serializer with specified initial capacity.
     *
     * @param initialCapacity the initial buffer capacity
     */
    public BcsSerializer(int initialCapacity) {
        this.buffer = new byte[initialCapacity];
        this.size = 0;
    }

    // ==========================================================================
    // BOOLEAN
    // ==========================================================================

    /**
     * Serialize a boolean value.
     *
     * @param value the boolean to serialize
     * @return this serializer for chaining
     */
    public BcsSerializer writeBool(boolean value) {
        ensureCapacity(1);
        buffer[size++] = (byte) (value ? 1 : 0);
        return this;
    }

    // ==========================================================================
    // UNSIGNED INTEGERS
    // ==========================================================================

    /**
     * Serialize an unsigned 8-bit integer.
     *
     * @param value the value (0-255)
     * @return this serializer for chaining
     */
    public BcsSerializer writeU8(short value) {
        if (value < 0 || value > 255) {
            throw BcsError.valueOutOfRange("u8", value);
        }
        ensureCapacity(1);
        buffer[size++] = (byte) value;
        return this;
    }

    /**
     * Serialize an unsigned 16-bit integer (little-endian).
     *
     * @param value the value (0-65535)
     * @return this serializer for chaining
     */
    public BcsSerializer writeU16(int value) {
        if (value < 0 || value > 0xFFFF) {
            throw BcsError.valueOutOfRange("u16", value);
        }
        ensureCapacity(2);
        buffer[size++] = (byte) value;
        buffer[size++] = (byte) (value >>> 8);
        return this;
    }

    /**
     * Serialize an unsigned 32-bit integer (little-endian).
     *
     * @param value the value (0 to 2^32-1)
     * @return this serializer for chaining
     */
    public BcsSerializer writeU32(long value) {
        if (value < 0 || value > 0xFFFFFFFFL) {
            throw BcsError.valueOutOfRange("u32", value);
        }
        ensureCapacity(4);
        buffer[size++] = (byte) value;
        buffer[size++] = (byte) (value >>> 8);
        buffer[size++] = (byte) (value >>> 16);
        buffer[size++] = (byte) (value >>> 24);
        return this;
    }

    /**
     * Serialize an unsigned 64-bit integer (little-endian).
     *
     * @param value the value (0 to 2^64-1, stored as long treating as unsigned)
     * @return this serializer for chaining
     */
    public BcsSerializer writeU64(long value) {
        ensureCapacity(8);
        buffer[size++] = (byte) value;
        buffer[size++] = (byte) (value >>> 8);
        buffer[size++] = (byte) (value >>> 16);
        buffer[size++] = (byte) (value >>> 24);
        buffer[size++] = (byte) (value >>> 32);
        buffer[size++] = (byte) (value >>> 40);
        buffer[size++] = (byte) (value >>> 48);
        buffer[size++] = (byte) (value >>> 56);
        return this;
    }

    /**
     * Serialize an unsigned 128-bit integer (little-endian).
     *
     * @param value the value (0 to 2^128-1)
     * @return this serializer for chaining
     */
    public BcsSerializer writeU128(BigInteger value) {
        if (value.signum() < 0 || value.compareTo(U128_MAX) > 0) {
            throw BcsError.valueOutOfRange("u128", value);
        }
        writeBigIntegerLE(value, 16);
        return this;
    }

    /**
     * Serialize an unsigned 256-bit integer (little-endian).
     *
     * @param value the value (0 to 2^256-1)
     * @return this serializer for chaining
     */
    public BcsSerializer writeU256(BigInteger value) {
        if (value.signum() < 0 || value.compareTo(U256_MAX) > 0) {
            throw BcsError.valueOutOfRange("u256", value);
        }
        writeBigIntegerLE(value, 32);
        return this;
    }

    /**
     * Serialize raw unsigned 128-bit integer from two longs (little-endian).
     * This is faster than BigInteger for values that fit in 128 bits.
     *
     * @param low the lower 64 bits
     * @param high the upper 64 bits
     * @return this serializer for chaining
     */
    public BcsSerializer writeU128Raw(long low, long high) {
        writeU64(low);
        writeU64(high);
        return this;
    }

    // ==========================================================================
    // SIGNED INTEGERS
    // ==========================================================================

    /**
     * Serialize a signed 8-bit integer (two's complement).
     *
     * @param value the value (-128 to 127)
     * @return this serializer for chaining
     */
    public BcsSerializer writeI8(byte value) {
        ensureCapacity(1);
        buffer[size++] = value;
        return this;
    }

    /**
     * Serialize a signed 16-bit integer (two's complement, little-endian).
     *
     * @param value the value (-32768 to 32767)
     * @return this serializer for chaining
     */
    public BcsSerializer writeI16(short value) {
        ensureCapacity(2);
        buffer[size++] = (byte) value;
        buffer[size++] = (byte) (value >> 8);
        return this;
    }

    /**
     * Serialize a signed 32-bit integer (two's complement, little-endian).
     *
     * @param value the value
     * @return this serializer for chaining
     */
    public BcsSerializer writeI32(int value) {
        ensureCapacity(4);
        buffer[size++] = (byte) value;
        buffer[size++] = (byte) (value >> 8);
        buffer[size++] = (byte) (value >> 16);
        buffer[size++] = (byte) (value >> 24);
        return this;
    }

    /**
     * Serialize a signed 64-bit integer (two's complement, little-endian).
     *
     * @param value the value
     * @return this serializer for chaining
     */
    public BcsSerializer writeI64(long value) {
        return writeU64(value); // Same bit representation
    }

    /**
     * Serialize a signed 128-bit integer (two's complement, little-endian).
     *
     * @param value the value
     * @return this serializer for chaining
     */
    public BcsSerializer writeI128(BigInteger value) {
        if (value.compareTo(I128_MIN) < 0 || value.compareTo(I128_MAX) > 0) {
            throw BcsError.valueOutOfRange("i128", value);
        }
        BigInteger unsigned = value.signum() < 0 ? value.add(TWO_POW_128) : value;
        writeBigIntegerLE(unsigned, 16);
        return this;
    }

    /**
     * Serialize a signed 256-bit integer (two's complement, little-endian).
     *
     * @param value the value
     * @return this serializer for chaining
     */
    public BcsSerializer writeI256(BigInteger value) {
        if (value.compareTo(I256_MIN) < 0 || value.compareTo(I256_MAX) > 0) {
            throw BcsError.valueOutOfRange("i256", value);
        }
        BigInteger unsigned = value.signum() < 0 ? value.add(TWO_POW_256) : value;
        writeBigIntegerLE(unsigned, 32);
        return this;
    }

    // ==========================================================================
    // ULEB128
    // ==========================================================================

    /**
     * Serialize a ULEB128-encoded unsigned integer.
     *
     * @param value the value (0 to 2^32-1)
     * @return this serializer for chaining
     */
    public BcsSerializer writeUleb128(long value) {
        // Inline ULEB128 encoding for better performance (avoids array allocation)
        if (value < 0 || value > Uleb128.MAX_U32) {
            throw BcsError.valueOutOfRange("uleb128", value);
        }

        // Fast path for small values (very common - vector lengths, etc.)
        if (value < 0x80) {
            ensureCapacity(1);
            buffer[size++] = (byte) value;
            return this;
        }

        // General case
        ensureCapacity(5); // Max 5 bytes for u32
        long remaining = value;
        do {
            int byteVal = (int) (remaining & 0x7F);
            remaining >>>= 7;
            if (remaining != 0) {
                byteVal |= 0x80;
            }
            buffer[size++] = (byte) byteVal;
        } while (remaining != 0);

        return this;
    }

    // ==========================================================================
    // BYTES AND STRINGS
    // ==========================================================================

    /**
     * Serialize a byte array (length-prefixed with ULEB128).
     *
     * @param value the bytes to serialize
     * @return this serializer for chaining
     */
    public BcsSerializer writeBytes(byte[] value) {
        if (value.length > MAX_SEQUENCE_LENGTH) {
            throw BcsError.exceededMaxLength(value.length);
        }
        writeUleb128(value.length);
        writeRawBytes(value);
        return this;
    }

    /**
     * Serialize a UTF-8 string (length-prefixed with ULEB128).
     *
     * @param value the string to serialize (must not be null)
     * @return this serializer for chaining
     * @throws NullPointerException if value is null
     */
    public BcsSerializer writeString(String value) {
        if (value == null) {
            throw new NullPointerException("String value cannot be null");
        }
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        return writeBytes(bytes);
    }

    /**
     * Serialize fixed-length bytes (no length prefix).
     *
     * @param value the bytes to serialize
     * @param length the expected length
     * @return this serializer for chaining
     */
    public BcsSerializer writeFixedBytes(byte[] value, int length) {
        if (value.length != length) {
            throw new IllegalArgumentException(
                    String.format("Expected %d bytes, got %d", length, value.length));
        }
        writeRawBytes(value);
        return this;
    }

    /**
     * Write raw bytes without length prefix.
     *
     * @param value the bytes to write
     */
    private void writeRawBytes(byte[] value) {
        ensureCapacity(value.length);
        System.arraycopy(value, 0, buffer, size, value.length);
        size += value.length;
    }

    // ==========================================================================
    // OPTION
    // ==========================================================================

    /**
     * Serialize an optional value.
     *
     * @param value the value or null
     * @param serializer function to serialize the inner value
     * @param <T> the type of the optional value
     * @return this serializer for chaining
     */
    public <T> BcsSerializer writeOption(T value, BiConsumer<BcsSerializer, T> serializer) {
        ensureCapacity(1);
        if (value == null) {
            buffer[size++] = 0;
        } else {
            buffer[size++] = 1;
            serializer.accept(this, value);
        }
        return this;
    }

    // ==========================================================================
    // VECTOR
    // ==========================================================================

    /**
     * Serialize a vector of values.
     *
     * @param values the list of values
     * @param serializer function to serialize each element
     * @param <T> the type of vector elements
     * @return this serializer for chaining
     */
    public <T> BcsSerializer writeVector(List<T> values, BiConsumer<BcsSerializer, T> serializer) {
        if (values.size() > MAX_SEQUENCE_LENGTH) {
            throw BcsError.exceededMaxLength(values.size());
        }
        writeUleb128(values.size());
        for (T value : values) {
            serializer.accept(this, value);
        }
        return this;
    }

    // ==========================================================================
    // ENUM
    // ==========================================================================

    /**
     * Enter an enum container and write its variant index (ULEB128).
     *
     * @param index the variant index
     * @return this serializer for chaining
     */
    public BcsSerializer enterEnum(int index) {
        enterContainer("enum");
        writeUleb128(index);
        return this;
    }

    /**
     * Leave the current enum container.
     *
     * @return this serializer for chaining
     */
    public BcsSerializer leaveEnum() {
        leaveContainer();
        return this;
    }

    /**
     * Write an enum variant index (ULEB128).
     *
     * @param index the variant index
     * @return this serializer for chaining
     */
    public BcsSerializer writeVariantIndex(int index) {
        return enterEnum(index);
    }

    // ==========================================================================
    // MAP
    // ==========================================================================

    /**
     * Serialize a map (sorted by key bytes).
     *
     * @param entries the map entries
     * @param keySerializer function to serialize keys
     * @param valueSerializer function to serialize values
     * @param <K> the key type
     * @param <V> the value type
     * @return this serializer for chaining
     */
    public <K, V> BcsSerializer writeMap(
            Map<K, V> entries,
            BiConsumer<BcsSerializer, K> keySerializer,
            BiConsumer<BcsSerializer, V> valueSerializer) {

        int mapSize = entries.size();
        if (mapSize > MAX_SEQUENCE_LENGTH) {
            throw BcsError.exceededMaxLength(mapSize);
        }

        // Early exit for empty maps
        if (mapSize == 0) {
            writeUleb128(0);
            return this;
        }

        // Serialize keys to get bytes for sorting
        // Pre-allocate array to avoid stream overhead
        @SuppressWarnings("unchecked")
        KeyEntry<K, V>[] keyEntries = new KeyEntry[mapSize];
        BcsSerializer keySer = new BcsSerializer(64); // Reuse for all keys

        int i = 0;
        for (Map.Entry<K, V> e : entries.entrySet()) {
            keySer.reset();
            keySerializer.accept(keySer, e.getKey());
            keyEntries[i++] = new KeyEntry<>(keySer.toBytes(), e.getKey(), e.getValue());
        }

        // Sort by key bytes using unsigned comparison
        Arrays.sort(keyEntries, (a, b) -> compareBytes(a.keyBytes, b.keyBytes));

        // Write length and sorted entries
        writeUleb128(keyEntries.length);
        for (KeyEntry<K, V> entry : keyEntries) {
            writeRawBytes(entry.keyBytes);
            valueSerializer.accept(this, entry.value);
        }

        return this;
    }

    /** Internal record for map key sorting. */
    private record KeyEntry<K, V>(byte[] keyBytes, K key, V value) {}

    // ==========================================================================
    // UTILITY
    // ==========================================================================

    /**
     * Get the serialized bytes.
     *
     * @return the serialized byte array
     */
    public byte[] toBytes() {
        return Arrays.copyOf(buffer, size);
    }

    /**
     * Get the current length in bytes.
     *
     * @return the number of bytes written
     */
    public int length() {
        return size;
    }

    /**
     * Reset this serializer for reuse.
     * More efficient than creating a new instance.
     */
    public void reset() {
        size = 0;
        currentDepth = 0;
    }

    // ==========================================================================
    // CONTAINER DEPTH
    // ==========================================================================

    /**
     * Enter a struct container for depth tracking.
     *
     * @return this serializer for chaining
     */
    public BcsSerializer enterStruct() {
        return enterStruct("");
    }

    /**
     * Enter a struct container for depth tracking.
     *
     * @param name optional struct name for error messages
     * @return this serializer for chaining
     */
    public BcsSerializer enterStruct(String name) {
        enterContainer(name);
        return this;
    }

    /**
     * Leave the current struct container.
     *
     * @return this serializer for chaining
     */
    public BcsSerializer leaveStruct() {
        leaveContainer();
        return this;
    }

    // ==========================================================================
    // PRIVATE HELPERS
    // ==========================================================================

    /**
     * Ensure the buffer has capacity for at least 'additional' more bytes.
     */
    private void ensureCapacity(int additional) {
        int required = size + additional;
        if (required > buffer.length) {
            // Grow by at least 50% or to required size, whichever is larger
            int newCapacity = Math.max(buffer.length + (buffer.length >> 1), required);
            buffer = Arrays.copyOf(buffer, newCapacity);
        }
    }

    private void writeBigIntegerLE(BigInteger value, int byteLength) {
        ensureCapacity(byteLength);
        byte[] bytes = value.toByteArray();
        int bytesLen = bytes.length;

        // BigInteger uses big-endian with possible leading sign byte
        // We need little-endian, padding with zeros if needed
        for (int i = 0; i < byteLength; i++) {
            int srcIndex = bytesLen - 1 - i;
            buffer[size++] = (srcIndex >= 0) ? bytes[srcIndex] : 0;
        }
    }

    private void enterContainer(String container) {
        if (currentDepth >= MAX_CONTAINER_DEPTH) {
            throw BcsError.exceededContainerDepth(container);
        }
        currentDepth++;
    }

    private void leaveContainer() {
        if (currentDepth > 0) {
            currentDepth--;
        }
    }

    /**
     * Compare two byte arrays as unsigned bytes (lexicographic).
     */
    private static int compareBytes(byte[] a, byte[] b) {
        // Use Arrays.compareUnsigned for potentially optimized comparison (Java 9+)
        return Arrays.compareUnsigned(a, b);
    }
}
