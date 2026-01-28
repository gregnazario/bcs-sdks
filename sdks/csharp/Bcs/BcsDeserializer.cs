using System.Buffers.Binary;
using System.Numerics;
using System.Text;

namespace Bcs;

/// <summary>
/// BCS Deserializer - Manual deserialization API.
/// </summary>
/// <remarks>
/// Provides explicit methods for deserializing each BCS type.
/// Use this for full control over deserialization.
/// </remarks>
/// <example>
/// <code>
/// var des = new BcsDeserializer(bytes);
/// byte value1 = des.ReadU8();
/// ulong value2 = des.ReadU64();
/// string value3 = des.ReadString();
/// des.CheckEnd();
/// </code>
/// </example>
public class BcsDeserializer
{
    // Pre-computed constants for signed integer conversion
    private static readonly BigInteger SignBit128 = BigInteger.One << 127;
    private static readonly BigInteger TwoPow128 = BigInteger.One << 128;
    private static readonly BigInteger SignBit256 = BigInteger.One << 255;
    private static readonly BigInteger TwoPow256 = BigInteger.One << 256;

    private readonly ReadOnlyMemory<byte> _data;
    private int _offset;
    private int _depth;

    /// <summary>Creates a new BCS deserializer.</summary>
    public BcsDeserializer(ReadOnlyMemory<byte> data)
    {
        _data = data;
        _offset = 0;
        _depth = 0;
    }

    /// <summary>Creates a new BCS deserializer from a byte array.</summary>
    public BcsDeserializer(byte[] data) : this(data.AsMemory())
    {
    }

    #region Boolean

    /// <summary>Deserializes a boolean value.</summary>
    public bool ReadBool()
    {
        EnsureBytes(1);
        var b = _data.Span[_offset++];
        return b switch
        {
            0 => false,
            1 => true,
            _ => throw BcsException.InvalidBoolean(b)
        };
    }

    #endregion

    #region Unsigned Integers

    /// <summary>Deserializes an unsigned 8-bit integer.</summary>
    public byte ReadU8()
    {
        EnsureBytes(1);
        return _data.Span[_offset++];
    }

    /// <summary>Deserializes an unsigned 16-bit integer (little-endian).</summary>
    public ushort ReadU16()
    {
        EnsureBytes(2);
        var value = BinaryPrimitives.ReadUInt16LittleEndian(_data.Span.Slice(_offset));
        _offset += 2;
        return value;
    }

    /// <summary>Deserializes an unsigned 32-bit integer (little-endian).</summary>
    public uint ReadU32()
    {
        EnsureBytes(4);
        var value = BinaryPrimitives.ReadUInt32LittleEndian(_data.Span.Slice(_offset));
        _offset += 4;
        return value;
    }

    /// <summary>Deserializes an unsigned 64-bit integer (little-endian).</summary>
    public ulong ReadU64()
    {
        EnsureBytes(8);
        var value = BinaryPrimitives.ReadUInt64LittleEndian(_data.Span.Slice(_offset));
        _offset += 8;
        return value;
    }

    /// <summary>Deserializes an unsigned 128-bit integer (little-endian).</summary>
    public BigInteger ReadU128()
    {
        EnsureBytes(16);
        return ReadBigIntegerLE(16, false);
    }

    /// <summary>Deserializes an unsigned 256-bit integer (little-endian).</summary>
    public BigInteger ReadU256()
    {
        EnsureBytes(32);
        return ReadBigIntegerLE(32, false);
    }

    #endregion

    #region Signed Integers

    /// <summary>Deserializes a signed 8-bit integer (two's complement).</summary>
    public sbyte ReadI8()
    {
        return unchecked((sbyte)ReadU8());
    }

    /// <summary>Deserializes a signed 16-bit integer (two's complement, little-endian).</summary>
    public short ReadI16()
    {
        EnsureBytes(2);
        var value = BinaryPrimitives.ReadInt16LittleEndian(_data.Span.Slice(_offset));
        _offset += 2;
        return value;
    }

    /// <summary>Deserializes a signed 32-bit integer (two's complement, little-endian).</summary>
    public int ReadI32()
    {
        EnsureBytes(4);
        var value = BinaryPrimitives.ReadInt32LittleEndian(_data.Span.Slice(_offset));
        _offset += 4;
        return value;
    }

    /// <summary>Deserializes a signed 64-bit integer (two's complement, little-endian).</summary>
    public long ReadI64()
    {
        EnsureBytes(8);
        var value = BinaryPrimitives.ReadInt64LittleEndian(_data.Span.Slice(_offset));
        _offset += 8;
        return value;
    }

    /// <summary>Deserializes a signed 128-bit integer (two's complement, little-endian).</summary>
    public BigInteger ReadI128()
    {
        EnsureBytes(16);
        return ReadBigIntegerLE(16, true);
    }

    /// <summary>Deserializes a signed 256-bit integer (two's complement, little-endian).</summary>
    public BigInteger ReadI256()
    {
        EnsureBytes(32);
        return ReadBigIntegerLE(32, true);
    }

    #endregion

    #region ULEB128

    /// <summary>Deserializes a ULEB128-encoded unsigned integer.</summary>
    public uint ReadUleb128()
    {
        Uleb128.Decode(_data.Span.Slice(_offset), out var value, out var bytesConsumed);
        _offset += bytesConsumed;
        return value;
    }

    #endregion

    #region Bytes and Strings

    /// <summary>Deserializes a byte array (length-prefixed with ULEB128).</summary>
    public byte[] ReadBytes()
    {
        var length = ReadUleb128();
        if (length > BcsSerializer.MaxSequenceLength)
        {
            throw BcsException.ExceededMaxLength(length);
        }
        return ReadFixedBytes((int)length);
    }

    /// <summary>Deserializes a UTF-8 string (length-prefixed with ULEB128).</summary>
    public string ReadString()
    {
        var bytes = ReadBytes();
        try
        {
            return Encoding.UTF8.GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            throw BcsException.InvalidUtf8();
        }
    }

    /// <summary>Deserializes fixed-length bytes (no length prefix).</summary>
    public byte[] ReadFixedBytes(int length)
    {
        EnsureBytes(length);
        var result = _data.Span.Slice(_offset, length).ToArray();
        _offset += length;
        return result;
    }

    #endregion

    #region Option

    /// <summary>Reads the option tag and returns whether a value is present.</summary>
    public bool ReadOptionTag()
    {
        EnsureBytes(1);
        var tag = _data.Span[_offset++];
        return tag switch
        {
            0 => false,
            1 => true,
            _ => throw BcsException.InvalidOption(tag)
        };
    }

    /// <summary>Deserializes an optional value.</summary>
    public T? ReadOption<T>(Func<BcsDeserializer, T> deserializer) where T : class
    {
        return ReadOptionTag() ? deserializer(this) : null;
    }

    /// <summary>Deserializes an optional value type.</summary>
    public T? ReadOptionValue<T>(Func<BcsDeserializer, T> deserializer) where T : struct
    {
        return ReadOptionTag() ? deserializer(this) : null;
    }

    #endregion

    #region Vector

    /// <summary>Reads the length prefix for a vector.</summary>
    public uint ReadVectorLength()
    {
        var length = ReadUleb128();
        if (length > BcsSerializer.MaxSequenceLength)
        {
            throw BcsException.ExceededMaxLength(length);
        }
        return length;
    }

    /// <summary>Deserializes a vector of values.</summary>
    public List<T> ReadVector<T>(Func<BcsDeserializer, T> deserializer)
    {
        var length = ReadVectorLength();
        var result = new List<T>((int)length);
        for (var i = 0u; i < length; i++)
        {
            result.Add(deserializer(this));
        }
        return result;
    }

    #endregion

    #region Enum

    /// <summary>Reads an enum variant index (ULEB128).</summary>
    public uint ReadVariantIndex()
    {
        return ReadUleb128();
    }

    #endregion

    #region Map

    /// <summary>Reads the length prefix for a map.</summary>
    public uint ReadMapLength()
    {
        return ReadVectorLength();
    }

    /// <summary>Gets the current position for key comparison.</summary>
    public int Position => _offset;

    /// <summary>Gets a slice of the data from start to current position.</summary>
    public ReadOnlySpan<byte> SliceFrom(int start) => _data.Span.Slice(start, _offset - start);

    /// <summary>Deserializes a map with key validation (sorted keys, no duplicates).</summary>
    /// <typeparam name="K">The key type.</typeparam>
    /// <typeparam name="V">The value type.</typeparam>
    /// <param name="keyDeserializer">Function to deserialize keys.</param>
    /// <param name="valueDeserializer">Function to deserialize values.</param>
    /// <returns>A dictionary containing the deserialized key-value pairs.</returns>
    /// <exception cref="BcsException">Thrown if keys are not sorted or contain duplicates.</exception>
    public Dictionary<K, V> ReadMap<K, V>(
        Func<BcsDeserializer, K> keyDeserializer,
        Func<BcsDeserializer, V> valueDeserializer) where K : notnull
    {
        var length = ReadMapLength();
        var result = new Dictionary<K, V>((int)length);
        byte[]? prevKeyBytes = null;

        for (var i = 0u; i < length; i++)
        {
            var keyStart = _offset;
            var key = keyDeserializer(this);
            var keyEnd = _offset;
            var keyBytes = _data.Span.Slice(keyStart, keyEnd - keyStart).ToArray();

            if (prevKeyBytes != null)
            {
                var cmp = CompareBytes(prevKeyBytes, keyBytes);
                if (cmp == 0)
                {
                    throw BcsException.DuplicateMapKey();
                }
                if (cmp > 0)
                {
                    throw BcsException.NonCanonicalMap();
                }
            }
            prevKeyBytes = keyBytes;

            var value = valueDeserializer(this);
            result[key] = value;
        }

        return result;
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
    public BcsDeserializer EnterStruct()
    {
        EnterContainer("struct");
        return this;
    }

    /// <summary>Leaves a struct container.</summary>
    public BcsDeserializer LeaveStruct()
    {
        LeaveContainer();
        return this;
    }

    /// <summary>Enters an enum container for depth tracking and reads the variant index.</summary>
    /// <returns>The enum variant index.</returns>
    /// <exception cref="BcsException">Thrown when container depth exceeds MaxContainerDepth (500).</exception>
    public uint EnterEnum()
    {
        EnterContainer("enum");
        return ReadVariantIndex();
    }

    /// <summary>Leaves an enum container.</summary>
    public BcsDeserializer LeaveEnum()
    {
        LeaveContainer();
        return this;
    }

    private void EnterContainer(string containerType)
    {
        if (_depth >= BcsSerializer.MaxContainerDepth)
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

    /// <summary>Verifies that all input has been consumed.</summary>
    public void CheckEnd()
    {
        if (_offset < _data.Length)
        {
            throw BcsException.RemainingInput(_data.Length - _offset);
        }
    }

    /// <summary>Gets the number of remaining bytes.</summary>
    public int Remaining => _data.Length - _offset;

    #endregion

    #region Private Helpers

    private void EnsureBytes(int count)
    {
        if (_offset + count > _data.Length)
        {
            throw BcsException.UnexpectedEof(count, _data.Length - _offset);
        }
    }

    private BigInteger ReadBigIntegerLE(int byteLength, bool signed)
    {
        // Read directly from span without allocation
        var span = _data.Span.Slice(_offset, byteLength);
        _offset += byteLength;

        var value = new BigInteger(span, isUnsigned: true, isBigEndian: false);

        if (signed)
        {
            // Use pre-computed constants for common sizes
            var (signBit, twoPow) = byteLength switch
            {
                16 => (SignBit128, TwoPow128),
                32 => (SignBit256, TwoPow256),
                _ => (BigInteger.One << (byteLength * 8 - 1), BigInteger.One << (byteLength * 8))
            };

            if (value >= signBit)
            {
                value -= twoPow;
            }
        }

        return value;
    }

    #endregion
}
