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

    private readonly MemoryStream _buffer = new();

    #region Boolean

    /// <summary>Serializes a boolean value.</summary>
    public BcsSerializer WriteBool(bool value)
    {
        _buffer.WriteByte(value ? (byte)1 : (byte)0);
        return this;
    }

    #endregion

    #region Unsigned Integers

    /// <summary>Serializes an unsigned 8-bit integer.</summary>
    public BcsSerializer WriteU8(byte value)
    {
        _buffer.WriteByte(value);
        return this;
    }

    /// <summary>Serializes an unsigned 16-bit integer (little-endian).</summary>
    public BcsSerializer WriteU16(ushort value)
    {
        Span<byte> bytes = stackalloc byte[2];
        BinaryPrimitives.WriteUInt16LittleEndian(bytes, value);
        _buffer.Write(bytes);
        return this;
    }

    /// <summary>Serializes an unsigned 32-bit integer (little-endian).</summary>
    public BcsSerializer WriteU32(uint value)
    {
        Span<byte> bytes = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(bytes, value);
        _buffer.Write(bytes);
        return this;
    }

    /// <summary>Serializes an unsigned 64-bit integer (little-endian).</summary>
    public BcsSerializer WriteU64(ulong value)
    {
        Span<byte> bytes = stackalloc byte[8];
        BinaryPrimitives.WriteUInt64LittleEndian(bytes, value);
        _buffer.Write(bytes);
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
        _buffer.WriteByte(unchecked((byte)value));
        return this;
    }

    /// <summary>Serializes a signed 16-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI16(short value)
    {
        Span<byte> bytes = stackalloc byte[2];
        BinaryPrimitives.WriteInt16LittleEndian(bytes, value);
        _buffer.Write(bytes);
        return this;
    }

    /// <summary>Serializes a signed 32-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI32(int value)
    {
        Span<byte> bytes = stackalloc byte[4];
        BinaryPrimitives.WriteInt32LittleEndian(bytes, value);
        _buffer.Write(bytes);
        return this;
    }

    /// <summary>Serializes a signed 64-bit integer (two's complement, little-endian).</summary>
    public BcsSerializer WriteI64(long value)
    {
        Span<byte> bytes = stackalloc byte[8];
        BinaryPrimitives.WriteInt64LittleEndian(bytes, value);
        _buffer.Write(bytes);
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
        var encoded = Uleb128.Encode(value);
        _buffer.Write(encoded);
        return this;
    }

    #endregion

    #region Bytes and Strings

    /// <summary>Serializes a byte array (length-prefixed with ULEB128).</summary>
    public BcsSerializer WriteBytes(ReadOnlySpan<byte> value)
    {
        if (value.Length > MaxSequenceLength)
        {
            throw BcsException.ExceededMaxLength((ulong)value.Length);
        }
        WriteUleb128((uint)value.Length);
        _buffer.Write(value);
        return this;
    }

    /// <summary>Serializes a UTF-8 string (length-prefixed with ULEB128).</summary>
    public BcsSerializer WriteString(string value)
    {
        var bytes = Encoding.UTF8.GetBytes(value);
        return WriteBytes(bytes);
    }

    /// <summary>Serializes fixed-length bytes (no length prefix).</summary>
    public BcsSerializer WriteFixedBytes(ReadOnlySpan<byte> value, int length)
    {
        if (value.Length != length)
        {
            throw BcsException.ValueOutOfRange("fixed_bytes", value.Length);
        }
        _buffer.Write(value);
        return this;
    }

    #endregion

    #region Option

    /// <summary>Writes the option tag for a nullable value.</summary>
    public BcsSerializer WriteOptionTag(bool hasValue)
    {
        _buffer.WriteByte(hasValue ? (byte)1 : (byte)0);
        return this;
    }

    /// <summary>Serializes an optional value.</summary>
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

    /// <summary>Serializes an optional value type.</summary>
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

    /// <summary>Serializes a vector of values.</summary>
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

    #endregion

    #region Utility

    /// <summary>Returns the serialized bytes as a new array.</summary>
    public byte[] ToArray() => _buffer.ToArray();

    /// <summary>Returns the current length in bytes.</summary>
    public int Length => (int)_buffer.Length;

    /// <summary>Clears the serializer for reuse.</summary>
    public void Clear() => _buffer.SetLength(0);

    #endregion

    #region Private Helpers

    private void WriteBigIntegerLE(BigInteger value, int byteLength, bool signed)
    {
        if (signed)
        {
            // For signed, convert negative to two's complement
            if (value.Sign < 0)
            {
                value += BigInteger.One << (byteLength * 8);
            }
        }

        var bytes = value.ToByteArray(isUnsigned: true, isBigEndian: false);
        Span<byte> result = stackalloc byte[byteLength];

        // Copy bytes (padding with zeros if needed)
        var copyLen = Math.Min(bytes.Length, byteLength);
        bytes.AsSpan(0, copyLen).CopyTo(result);

        _buffer.Write(result);
    }

    #endregion
}
