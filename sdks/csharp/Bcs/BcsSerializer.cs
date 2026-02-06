using System.Buffers;
using System.Buffers.Binary;
using System.Numerics;
using System.Text;

namespace Bcs;

/// <summary>
/// BCS Serializer - Manual serialization API.
/// </summary>
/// <remarks>
/// Provides explicit methods for serializing each BCS type.
/// Use this for full control over serialization.
/// </remarks>
/// <example>
/// <code>
/// var ser = new BcsSerializer();
/// ser.WriteU8(1);
/// ser.WriteU64(100);
/// ser.WriteString("hello");
/// byte[] bytes = ser.ToArray();
/// </code>
/// </example>
public class BcsSerializer
{
    /// <summary>Maximum allowed sequence length.</summary>
    public const int MaxSequenceLength = int.MaxValue; // 2^31 - 1

    /// <summary>Maximum allowed container nesting depth.</summary>
    public const int MaxContainerDepth = 500;

    private const int DefaultCapacity = 256;

    private byte[] _buffer;
    private int _size;
    private int _depth;

    /// <summary>Creates a new BCS serializer with default capacity.</summary>
    public BcsSerializer() : this(DefaultCapacity)
    {
    }

    /// <summary>Creates a new BCS serializer with specified initial capacity.</summary>
    public BcsSerializer(int initialCapacity)
    {
        _buffer = new byte[initialCapacity];
        _size = 0;
        _depth = 0;
    }

    #region Boolean

    /// <summary>Serializes a boolean value (<c>0x00</c> = false, <c>0x01</c> = true).</summary>
    /// <param name="value">The boolean to serialize.</param>
    /// <returns>This serializer for method chaining.</returns>
    public BcsSerializer WriteBool(bool value)
    {
        EnsureCapacity(1);
        _buffer[_size++] = value ? (byte)1 : (byte)0;
        return this;
    }

    #endregion

    #region Unsigned Integers

    /// <summary>Serializes an unsigned 8-bit integer.</summary>
    /// <param name="value">Value to serialize (0–255).</param>
    /// <returns>This serializer for method chaining.</returns>
    public BcsSerializer WriteU8(byte value)
    {
        EnsureCapacity(1);
        _buffer[_size++] = value;
        return this;
    }

    /// <summary>Serializes an unsigned 16-bit integer (little-endian).</summary>
    /// <param name="value">Value to serialize.</param>
    /// <returns>This serializer for method chaining.</returns>
    public BcsSerializer WriteU16(ushort value)
    {
        EnsureCapacity(2);
        BinaryPrimitives.WriteUInt16LittleEndian(_buffer.AsSpan(_size), value);
        _size += 2;
        return this;
    }

    /// <summary>Serializes an unsigned 32-bit integer (little-endian).</summary>
    /// <param name="value">Value to serialize.</param>
    /// <returns>This serializer for method chaining.</returns>
    public BcsSerializer WriteU32(uint value)
    {
        EnsureCapacity(4);
        BinaryPrimitives.WriteUInt32LittleEndian(_buffer.AsSpan(_size), value);
        _size += 4;
        return this;
    }

    /// <summary>Serializes an unsigned 64-bit integer (little-endian).</summary>
    /// <param name="value">Value to serialize.</param>
    /// <returns>This serializer for method chaining.</returns>
    public BcsSerializer WriteU64(ulong value)
    {
        EnsureCapacity(8);
        BinaryPrimitives.WriteUInt64LittleEndian(_buffer.AsSpan(_size), value);
        _size += 8;
        return this;
    }

    /// <summary>Serializes an unsigned 128-bit integer (little-endian).</summary>
    public BcsSerializer WriteU128(BigInteger value)
    {
        WriteBigIntegerLE(value, 16, false);
        return this;
    }

    /// <summary>Serializes an unsigned 256-bit integer (little-endian).</summary>
    public BcsSerializer WriteU256(BigInteger value)
    {
        WriteBigIntegerLE(value, 32, false);
        return this;
    }

    #endregion

    #region Signed Integers

    /// <summary>Serializes a signed 8-bit integer (two's complement).</summary>
    public BcsSerializer WriteI8(sbyte value)
    {
        EnsureCapacity(1);
        _buffer[_size++] = unchecked((byte)value);
        return this;
    }

    /// <summary>Serializes a signed 16-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI16(short value)
    {
        EnsureCapacity(2);
        BinaryPrimitives.WriteInt16LittleEndian(_buffer.AsSpan(_size), value);
        _size += 2;
        return this;
    }

    /// <summary>Serializes a signed 32-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI32(int value)
    {
        EnsureCapacity(4);
        BinaryPrimitives.WriteInt32LittleEndian(_buffer.AsSpan(_size), value);
        _size += 4;
        return this;
    }

    /// <summary>Serializes a signed 64-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI64(long value)
    {
        EnsureCapacity(8);
        BinaryPrimitives.WriteInt64LittleEndian(_buffer.AsSpan(_size), value);
        _size += 8;
        return this;
    }

    /// <summary>Serializes a signed 128-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI128(BigInteger value)
    {
        WriteBigIntegerLE(value, 16, true);
        return this;
    }

    /// <summary>Serializes a signed 256-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI256(BigInteger value)
    {
        WriteBigIntegerLE(value, 32, true);
        return this;
    }

    #endregion

    #region ULEB128

    /// <summary>Serializes a ULEB128-encoded unsigned integer.</summary>
    public BcsSerializer WriteUleb128(uint value)
    {
        // Inline ULEB128 encoding for better performance (avoids allocation)
        // Fast path for small values (most common - vector lengths, etc.)
        if (value < 0x80)
        {
            EnsureCapacity(1);
            _buffer[_size++] = (byte)value;
            return this;
        }

        // General case
        EnsureCapacity(5); // Max 5 bytes for u32
        var remaining = value;
        do
        {
            var b = (byte)(remaining & 0x7F);
            remaining >>= 7;
            if (remaining != 0)
            {
                b |= 0x80;
            }
            _buffer[_size++] = b;
        } while (remaining != 0);

        return this;
    }

    #endregion

    #region Bytes and Strings

    /// <summary>Serializes a byte array with ULEB128 length prefix.</summary>
    /// <param name="value">Bytes to serialize.</param>
    /// <returns>This serializer for method chaining.</returns>
    /// <exception cref="BcsException">Thrown when length exceeds <see cref="MaxSequenceLength"/>.</exception>
    public BcsSerializer WriteBytes(ReadOnlySpan<byte> value)
    {
        if (value.Length > MaxSequenceLength)
        {
            throw BcsException.ExceededMaxLength((ulong)value.Length);
        }
        WriteUleb128((uint)value.Length);
        WriteRawBytes(value);
        return this;
    }

    /// <summary>Serializes a UTF-8 string with ULEB128 length prefix.</summary>
    /// <param name="value">String to serialize.</param>
    /// <returns>This serializer for method chaining.</returns>
    /// <exception cref="BcsException">Thrown when byte length exceeds <see cref="MaxSequenceLength"/>.</exception>
    public BcsSerializer WriteString(string value)
    {
        // Get byte count first to avoid intermediate allocation when possible
        var byteCount = Encoding.UTF8.GetByteCount(value);
        if (byteCount > MaxSequenceLength)
        {
            throw BcsException.ExceededMaxLength((ulong)byteCount);
        }
        WriteUleb128((uint)byteCount);
        EnsureCapacity(byteCount);
        Encoding.UTF8.GetBytes(value, _buffer.AsSpan(_size));
        _size += byteCount;
        return this;
    }

    /// <summary>Serializes fixed-length bytes (no length prefix).</summary>
    public BcsSerializer WriteFixedBytes(ReadOnlySpan<byte> value, int length)
    {
        if (value.Length != length)
        {
            throw BcsException.ValueOutOfRange("fixed_bytes", value.Length);
        }
        WriteRawBytes(value);
        return this;
    }

    /// <summary>Writes raw bytes without length prefix.</summary>
    private void WriteRawBytes(ReadOnlySpan<byte> value)
    {
        EnsureCapacity(value.Length);
        value.CopyTo(_buffer.AsSpan(_size));
        _size += value.Length;
    }

    #endregion

    #region Option

    /// <summary>Writes the option tag for a nullable value.</summary>
    public BcsSerializer WriteOptionTag(bool hasValue)
    {
        EnsureCapacity(1);
        _buffer[_size++] = hasValue ? (byte)1 : (byte)0;
        return this;
    }

    /// <summary>Serializes an optional reference-type value (<c>None</c> = <c>0x00</c>, <c>Some</c> = <c>0x01</c> + value).</summary>
    /// <typeparam name="T">The type of the optional value.</typeparam>
    /// <param name="value">The value, or <c>null</c> for None.</param>
    /// <param name="serializer">Action to serialize the inner value if present.</param>
    /// <returns>This serializer for method chaining.</returns>
    public BcsSerializer WriteOption<T>(T? value, Action<BcsSerializer, T> serializer) where T : class
    {
        if (value is null)
        {
            WriteOptionTag(false);
        }
        else
        {
            WriteOptionTag(true);
            serializer(this, value);
        }
        return this;
    }

    /// <summary>Serializes an optional value-type value (<c>None</c> = <c>0x00</c>, <c>Some</c> = <c>0x01</c> + value).</summary>
    /// <typeparam name="T">The type of the optional value.</typeparam>
    /// <param name="value">The nullable value, or <c>null</c> for None.</param>
    /// <param name="serializer">Action to serialize the inner value if present.</param>
    /// <returns>This serializer for method chaining.</returns>
    public BcsSerializer WriteOption<T>(T? value, Action<BcsSerializer, T> serializer) where T : struct
    {
        if (value is null)
        {
            WriteOptionTag(false);
        }
        else
        {
            WriteOptionTag(true);
            serializer(this, value.Value);
        }
        return this;
    }

    #endregion

    #region Vector

    /// <summary>Writes the length prefix for a vector.</summary>
    public BcsSerializer WriteVectorLength(int length)
    {
        if (length > MaxSequenceLength)
        {
            throw BcsException.ExceededMaxLength((ulong)length);
        }
        WriteUleb128((uint)length);
        return this;
    }

    /// <summary>Serializes a vector of values with ULEB128 length prefix.</summary>
    /// <typeparam name="T">The element type.</typeparam>
    /// <param name="values">The list of values to serialize.</param>
    /// <param name="serializer">Action to serialize each element.</param>
    /// <returns>This serializer for method chaining.</returns>
    /// <exception cref="BcsException">Thrown when list count exceeds <see cref="MaxSequenceLength"/>.</exception>
    public BcsSerializer WriteVector<T>(IReadOnlyList<T> values, Action<BcsSerializer, T> serializer)
    {
        WriteVectorLength(values.Count);
        foreach (var value in values)
        {
            serializer(this, value);
        }
        return this;
    }

    #endregion

    #region Enum

    /// <summary>Writes an enum variant index (ULEB128).</summary>
    public BcsSerializer WriteVariantIndex(uint index)
    {
        return WriteUleb128(index);
    }

    #endregion

    #region Map

    /// <summary>Writes the length prefix for a map.</summary>
    public BcsSerializer WriteMapLength(int length)
    {
        return WriteVectorLength(length);
    }

    /// <summary>Serializes a map with keys sorted by their serialized bytes.</summary>
    /// <typeparam name="K">The key type.</typeparam>
    /// <typeparam name="V">The value type.</typeparam>
    /// <param name="entries">The key-value pairs to serialize.</param>
    /// <param name="keySerializer">Function to serialize keys.</param>
    /// <param name="valueSerializer">Function to serialize values.</param>
    /// <returns>This serializer for chaining.</returns>
    public BcsSerializer WriteMap<K, V>(
        IEnumerable<KeyValuePair<K, V>> entries,
        Action<BcsSerializer, K> keySerializer,
        Action<BcsSerializer, V> valueSerializer)
    {
        // Serialize keys to get their byte representation for sorting
        var serializedEntries = new List<(byte[] keyBytes, V value)>();
        var tempSerializer = new BcsSerializer();

        foreach (var entry in entries)
        {
            tempSerializer.Clear();
            keySerializer(tempSerializer, entry.Key);
            // Store key bytes and value
            serializedEntries.Add((tempSerializer.ToArray(), entry.Value));
        }

        // Sort by serialized key bytes
        serializedEntries.Sort((a, b) => CompareBytes(a.keyBytes, b.keyBytes));

        // Write the sorted entries using pre-serialized key bytes
        WriteMapLength(serializedEntries.Count);
        foreach (var (keyBytes, value) in serializedEntries)
        {
            // Use pre-serialized key bytes directly instead of re-serializing
            EnsureCapacity(keyBytes.Length);
            Buffer.BlockCopy(keyBytes, 0, _buffer, _size, keyBytes.Length);
            _size += keyBytes.Length;
            valueSerializer(this, value);
        }

        return this;
    }

    /// <summary>Compare two byte arrays lexicographically (unsigned).</summary>
    private static int CompareBytes(byte[] a, byte[] b)
    {
        var minLen = Math.Min(a.Length, b.Length);
        for (var i = 0; i < minLen; i++)
        {
            if (a[i] < b[i]) return -1;
            if (a[i] > b[i]) return 1;
        }
        return a.Length.CompareTo(b.Length);
    }

    #endregion

    #region Container Depth

    /// <summary>Gets the current container nesting depth.</summary>
    public int ContainerDepth => _depth;

    /// <summary>Enters a struct container for depth tracking.</summary>
    /// <exception cref="BcsException">Thrown when container depth exceeds MaxContainerDepth (500).</exception>
    public BcsSerializer EnterStruct()
    {
        EnterContainer("struct");
        return this;
    }

    /// <summary>Leaves a struct container.</summary>
    public BcsSerializer LeaveStruct()
    {
        LeaveContainer();
        return this;
    }

    /// <summary>Enters an enum container for depth tracking and writes the variant index.</summary>
    /// <param name="variantIndex">The enum variant index.</param>
    /// <exception cref="BcsException">Thrown when container depth exceeds MaxContainerDepth (500).</exception>
    public BcsSerializer EnterEnum(uint variantIndex)
    {
        EnterContainer("enum");
        WriteVariantIndex(variantIndex);
        return this;
    }

    /// <summary>Leaves an enum container.</summary>
    public BcsSerializer LeaveEnum()
    {
        LeaveContainer();
        return this;
    }

    private void EnterContainer(string containerType)
    {
        if (_depth >= MaxContainerDepth)
        {
            throw BcsException.ExceededContainerDepth(containerType);
        }
        _depth++;
    }

    private void LeaveContainer()
    {
        if (_depth > 0)
        {
            _depth--;
        }
    }

    #endregion

    #region Utility

    /// <summary>Returns the serialized bytes as a new array.</summary>
    /// <returns>A new byte array containing a copy of the serialized data.</returns>
    public byte[] ToArray() => _buffer.AsSpan(0, _size).ToArray();

    /// <summary>Returns the serialized bytes as a read-only span (zero-copy).</summary>
    /// <returns>A span over the internal buffer. Only valid until the next write or <see cref="Clear"/>.</returns>
    public ReadOnlySpan<byte> AsSpan() => _buffer.AsSpan(0, _size);

    /// <summary>Gets the current number of serialized bytes.</summary>
    public int Length => _size;

    /// <summary>Clears the serializer for reuse.</summary>
    public void Clear() => _size = 0;

    /// <summary>Resets the serializer for reuse (alias for Clear).</summary>
    public void Reset() => _size = 0;

    #endregion

    #region Private Helpers

    private void EnsureCapacity(int additional)
    {
        // Check for overflow before addition
        if (additional > int.MaxValue - _size)
        {
            throw BcsException.ExceededMaxLength((ulong)_size + (ulong)additional);
        }
        var required = _size + additional;
        if (required > _buffer.Length)
        {
            // Grow by at least 50% or to required size, with overflow check
            var growth = _buffer.Length >> 1;
            var newCapacity = (_buffer.Length > int.MaxValue - growth)
                ? required  // Can't grow by 50%, just use required
                : Math.Max(_buffer.Length + growth, required);
            Array.Resize(ref _buffer, newCapacity);
        }
    }

    private void WriteBigIntegerLE(BigInteger value, int byteLength, bool signed)
    {
        if (signed && value.Sign < 0)
        {
            // Convert negative to two's complement
            value += BigInteger.One << (byteLength * 8);
        }

        EnsureCapacity(byteLength);

        // Try to write directly to our buffer
        if (value.TryWriteBytes(_buffer.AsSpan(_size, byteLength), out var bytesWritten, isUnsigned: true, isBigEndian: false))
        {
            // Pad with zeros if needed
            if (bytesWritten < byteLength)
            {
                _buffer.AsSpan(_size + bytesWritten, byteLength - bytesWritten).Clear();
            }
        }
        else
        {
            // Fallback: value is larger than expected (shouldn't happen with valid input)
            var bytes = value.ToByteArray(isUnsigned: true, isBigEndian: false);
            var copyLen = Math.Min(bytes.Length, byteLength);
            bytes.AsSpan(0, copyLen).CopyTo(_buffer.AsSpan(_size));
            if (copyLen < byteLength)
            {
                _buffer.AsSpan(_size + copyLen, byteLength - copyLen).Clear();
            }
        }

        _size += byteLength;
    }

    #endregion
}
