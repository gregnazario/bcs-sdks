namespace Bcs;

/// <summary>
/// ULEB128 encoding and decoding utilities.
/// </summary>
/// <remarks>
/// ULEB128 (Unsigned Little-Endian Base 128) is a variable-length encoding
/// for unsigned integers. Each byte contributes 7 bits of data, with the
/// high bit indicating whether more bytes follow.
/// </remarks>
public static class Uleb128
{
    /// <summary>Maximum value that can be encoded (u32 max).</summary>
    public const uint MaxU32 = uint.MaxValue;

    // Pre-allocated arrays for common small values (0-127 need only 1 byte)
    private static readonly byte[][] SmallValueCache = CreateSmallValueCache();

    private static byte[][] CreateSmallValueCache()
    {
        var cache = new byte[128][];
        for (var i = 0; i < 128; i++)
        {
            cache[i] = [(byte)i];
        }
        return cache;
    }

    /// <summary>
    /// Encodes an unsigned integer as ULEB128.
    /// </summary>
    /// <param name="value">The value to encode (must be 0 to 2^32-1).</param>
    /// <returns>The ULEB128 encoded bytes.</returns>
    public static byte[] Encode(uint value)
    {
        // Fast path for small values (most common case - vector lengths, etc.)
        if (value < 128)
        {
            return SmallValueCache[value];
        }

        // Fast path for 2-byte values (128-16383)
        if (value < 0x4000)
        {
            return [(byte)((value & 0x7F) | 0x80), (byte)(value >> 7)];
        }

        // General case: use stackalloc and copy
        Span<byte> buffer = stackalloc byte[5];
        var length = EncodeTo(buffer, value);
        return buffer[..length].ToArray();
    }

    /// <summary>
    /// Encodes a ULEB128 value directly into a span.
    /// </summary>
    /// <param name="destination">The destination span (must be at least 5 bytes).</param>
    /// <param name="value">The value to encode.</param>
    /// <returns>The number of bytes written.</returns>
    public static int EncodeTo(Span<byte> destination, uint value)
    {
        var pos = 0;
        var remaining = value;

        do
        {
            var b = (byte)(remaining & 0x7F);
            remaining >>= 7;
            if (remaining != 0)
            {
                b |= 0x80;
            }
            destination[pos++] = b;
        } while (remaining != 0);

        return pos;
    }

    /// <summary>
    /// Decodes a ULEB128 value from a byte span.
    /// </summary>
    /// <param name="data">The data to decode from.</param>
    /// <param name="value">The decoded value.</param>
    /// <param name="bytesConsumed">The number of bytes consumed.</param>
    /// <exception cref="BcsException">If decoding fails.</exception>
    public static void Decode(ReadOnlySpan<byte> data, out uint value, out int bytesConsumed)
    {
        value = 0;
        var shift = 0;
        bytesConsumed = 0;

        while (true)
        {
            if (bytesConsumed >= data.Length)
            {
                throw BcsException.UnexpectedEof();
            }

            var b = data[bytesConsumed];
            bytesConsumed++;

            // Check for overflow (5 bytes max for u32)
            if (bytesConsumed == 5)
            {
                if (b >= 0x10)
                {
                    throw BcsException.Uleb128Overflow();
                }
                value |= (uint)b << shift;
                return;
            }

            var digit = (uint)(b & 0x7F);
            value |= digit << shift;

            if ((b & 0x80) == 0)
            {
                // Last byte - check for non-canonical encoding
                if (bytesConsumed > 1 && b == 0)
                {
                    throw BcsException.NonCanonicalUleb128();
                }
                return;
            }

            shift += 7;
        }
    }

    /// <summary>
    /// Returns the number of bytes needed to encode a value.
    /// </summary>
    /// <param name="value">The value to measure.</param>
    /// <returns>The number of bytes needed.</returns>
    public static int EncodedSize(uint value)
    {
        if (value == 0)
        {
            return 1;
        }

        var size = 0;
        var remaining = value;
        while (remaining > 0)
        {
            remaining >>= 7;
            size++;
        }
        return size;
    }
}
