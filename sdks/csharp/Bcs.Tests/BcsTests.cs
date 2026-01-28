using System.Numerics;
using System.Text.Json;
using Xunit;

namespace Bcs.Tests;

public class BcsTests
{
    private static readonly JsonDocument? TestVectors;

    static BcsTests()
    {
        var vectorsPath = Environment.GetEnvironmentVariable("TEST_VECTORS") ?? "../../test-vectors";
        var filePath = Path.Combine(vectorsPath, "bcs-comprehensive.json");
        if (File.Exists(filePath))
        {
            var json = File.ReadAllText(filePath);
            TestVectors = JsonDocument.Parse(json);
        }
    }

    private static byte[] HexToBytes(string hex)
    {
        var bytes = new byte[hex.Length / 2];
        for (var i = 0; i < bytes.Length; i++)
        {
            bytes[i] = Convert.ToByte(hex.Substring(i * 2, 2), 16);
        }
        return bytes;
    }

    private static string BytesToHex(byte[] bytes)
    {
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static IEnumerable<JsonElement>? GetTestVectors(params string[] path)
    {
        if (TestVectors == null) return null;

        JsonElement current = TestVectors.RootElement;
        foreach (var key in path)
        {
            if (!current.TryGetProperty(key, out current))
            {
                return null;
            }
        }
        return current.ValueKind == JsonValueKind.Array
            ? current.EnumerateArray()
            : null;
    }

    #region Boolean Tests

    [Fact]
    public void SerializeTrue()
    {
        var ser = new BcsSerializer();
        ser.WriteBool(true);
        Assert.Equal("01", BytesToHex(ser.ToArray()));
    }

    [Fact]
    public void SerializeFalse()
    {
        var ser = new BcsSerializer();
        ser.WriteBool(false);
        Assert.Equal("00", BytesToHex(ser.ToArray()));
    }

    [Fact]
    public void DeserializeTrue()
    {
        var des = new BcsDeserializer(HexToBytes("01"));
        Assert.True(des.ReadBool());
    }

    [Fact]
    public void DeserializeFalse()
    {
        var des = new BcsDeserializer(HexToBytes("00"));
        Assert.False(des.ReadBool());
    }

    [Fact]
    public void RejectInvalidBoolean()
    {
        var des = new BcsDeserializer(HexToBytes("02"));
        var ex = Assert.Throws<BcsException>(() => des.ReadBool());
        Assert.Equal(BcsErrorType.InvalidBoolean, ex.ErrorType);
    }

    #endregion

    #region Unsigned Integer Tests

    [Fact]
    public void U8TestVectors()
    {
        var vectors = GetTestVectors("primitives", "u8", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var name = tc.GetProperty("name").GetString();
            var value = (byte)tc.GetProperty("value").GetInt32();
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteU8(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadU8());
        }
    }

    [Fact]
    public void U16TestVectors()
    {
        var vectors = GetTestVectors("primitives", "u16", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var value = (ushort)tc.GetProperty("value").GetInt32();
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteU16(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadU16());
        }
    }

    [Fact]
    public void U32TestVectors()
    {
        var vectors = GetTestVectors("primitives", "u32", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var value = tc.GetProperty("value").GetUInt32();
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteU32(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadU32());
        }
    }

    [Fact]
    public void U64TestVectors()
    {
        var vectors = GetTestVectors("primitives", "u64", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var valueStr = tc.GetProperty("value").GetString()!;
            var value = ulong.Parse(valueStr);
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteU64(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadU64());
        }
    }

    [Fact]
    public void U128TestVectors()
    {
        var vectors = GetTestVectors("primitives", "u128", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var valueStr = tc.GetProperty("value").GetString()!;
            var value = BigInteger.Parse(valueStr);
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteU128(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadU128());
        }
    }

    [Fact]
    public void U256TestVectors()
    {
        var vectors = GetTestVectors("primitives", "u256", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var valueStr = tc.GetProperty("value").GetString()!;
            var value = BigInteger.Parse(valueStr);
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteU256(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadU256());
        }
    }

    #endregion

    #region Signed Integer Tests

    [Fact]
    public void I8TestVectors()
    {
        var vectors = GetTestVectors("primitives", "i8", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var value = (sbyte)tc.GetProperty("value").GetInt32();
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteI8(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadI8());
        }
    }

    [Fact]
    public void I16TestVectors()
    {
        var vectors = GetTestVectors("primitives", "i16", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var value = (short)tc.GetProperty("value").GetInt32();
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteI16(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadI16());
        }
    }

    [Fact]
    public void I32TestVectors()
    {
        var vectors = GetTestVectors("primitives", "i32", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var value = tc.GetProperty("value").GetInt32();
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteI32(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadI32());
        }
    }

    [Fact]
    public void I64TestVectors()
    {
        var vectors = GetTestVectors("primitives", "i64", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var valueStr = tc.GetProperty("value").GetString()!;
            var value = long.Parse(valueStr);
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteI64(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadI64());
        }
    }

    [Fact]
    public void I128TestVectors()
    {
        var vectors = GetTestVectors("primitives", "i128", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var valueStr = tc.GetProperty("value").GetString()!;
            var value = BigInteger.Parse(valueStr);
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteI128(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadI128());
        }
    }

    [Fact]
    public void I256TestVectors()
    {
        var vectors = GetTestVectors("primitives", "i256", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var valueStr = tc.GetProperty("value").GetString()!;
            var value = BigInteger.Parse(valueStr);
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteI256(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadI256());
        }
    }

    #endregion

    #region ULEB128 Tests

    [Fact]
    public void Uleb128TestVectors()
    {
        var vectors = GetTestVectors("uleb128", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var value = tc.GetProperty("value").GetUInt32();
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var encoded = Uleb128.Encode(value);
            Assert.Equal(bcsHex, BytesToHex(encoded));

            Uleb128.Decode(HexToBytes(bcsHex), out var decoded, out _);
            Assert.Equal(value, decoded);
        }
    }

    [Fact]
    public void RejectNonCanonicalUleb128()
    {
        // 0x80 0x00 is non-canonical for 0
        var ex = Assert.Throws<BcsException>(() =>
            Uleb128.Decode(new byte[] { 0x80, 0x00 }, out _, out _));
        Assert.Equal(BcsErrorType.NonCanonicalUleb128, ex.ErrorType);
    }

    [Fact]
    public void RejectUleb128Overflow()
    {
        // 6 bytes with continuation bits
        var ex = Assert.Throws<BcsException>(() =>
            Uleb128.Decode(new byte[] { 0x80, 0x80, 0x80, 0x80, 0x80, 0x01 }, out _, out _));
        Assert.Equal(BcsErrorType.Uleb128Overflow, ex.ErrorType);
    }

    #endregion

    #region String Tests

    [Fact]
    public void StringTestVectors()
    {
        var vectors = GetTestVectors("strings", "valid");
        if (vectors == null) return;

        foreach (var tc in vectors)
        {
            var value = tc.GetProperty("value").GetString()!;
            var bcsHex = tc.GetProperty("bcs_hex").GetString()!;

            var ser = new BcsSerializer();
            ser.WriteString(value);
            Assert.Equal(bcsHex, BytesToHex(ser.ToArray()));

            var des = new BcsDeserializer(HexToBytes(bcsHex));
            Assert.Equal(value, des.ReadString());
        }
    }

    #endregion

    #region Option Tests

    [Fact]
    public void SerializeNone()
    {
        var ser = new BcsSerializer();
        ser.WriteOptionTag(false);
        Assert.Equal("00", BytesToHex(ser.ToArray()));
    }

    [Fact]
    public void SerializeSome()
    {
        var ser = new BcsSerializer();
        ser.WriteOptionTag(true);
        ser.WriteU8(42);
        Assert.Equal("012a", BytesToHex(ser.ToArray()));
    }

    [Fact]
    public void DeserializeNone()
    {
        var des = new BcsDeserializer(HexToBytes("00"));
        Assert.False(des.ReadOptionTag());
    }

    [Fact]
    public void DeserializeSome()
    {
        var des = new BcsDeserializer(HexToBytes("012a"));
        Assert.True(des.ReadOptionTag());
        Assert.Equal((byte)42, des.ReadU8());
    }

    [Fact]
    public void RejectInvalidOptionTag()
    {
        var des = new BcsDeserializer(HexToBytes("02"));
        var ex = Assert.Throws<BcsException>(() => des.ReadOptionTag());
        Assert.Equal(BcsErrorType.InvalidOption, ex.ErrorType);
    }

    #endregion

    #region Vector Tests

    [Fact]
    public void SerializeEmptyVector()
    {
        var ser = new BcsSerializer();
        ser.WriteVectorLength(0);
        Assert.Equal("00", BytesToHex(ser.ToArray()));
    }

    [Fact]
    public void SerializeVector123()
    {
        var ser = new BcsSerializer();
        ser.WriteVector(new byte[] { 1, 2, 3 }, (s, v) => s.WriteU8(v));
        Assert.Equal("03010203", BytesToHex(ser.ToArray()));
    }

    [Fact]
    public void DeserializeEmptyVector()
    {
        var des = new BcsDeserializer(HexToBytes("00"));
        var length = des.ReadVectorLength();
        Assert.Equal(0u, length);
    }

    [Fact]
    public void DeserializeVector123()
    {
        var des = new BcsDeserializer(HexToBytes("03010203"));
        var result = des.ReadVector(d => d.ReadU8());
        Assert.Equal(new byte[] { 1, 2, 3 }, result);
    }

    #endregion

    #region Error Tests

    [Fact]
    public void RemainingInput()
    {
        var des = new BcsDeserializer(HexToBytes("0001"));
        des.ReadBool();
        var ex = Assert.Throws<BcsException>(des.CheckEnd);
        Assert.Equal(BcsErrorType.RemainingInput, ex.ErrorType);
    }

    [Fact]
    public void UnexpectedEofOnU64()
    {
        var des = new BcsDeserializer(HexToBytes("010203"));
        var ex = Assert.Throws<BcsException>(() => des.ReadU64());
        Assert.Equal(BcsErrorType.UnexpectedEof, ex.ErrorType);
    }

    [Fact]
    public void UnexpectedEofOnEmptyInput()
    {
        var des = new BcsDeserializer(Array.Empty<byte>());
        var ex = Assert.Throws<BcsException>(() => des.ReadU8());
        Assert.Equal(BcsErrorType.UnexpectedEof, ex.ErrorType);
    }

    #endregion

    #region Round-Trip Tests

    [Fact]
    public void ComplexStruct()
    {
        // Simulate a Transfer struct: sender (32 bytes), recipient (32 bytes), amount (u64)
        var sender = new byte[32];
        sender[31] = 1;
        var recipient = new byte[32];
        recipient[31] = 2;
        var amount = 1000000ul;

        var ser = new BcsSerializer();
        ser.WriteFixedBytes(sender, 32);
        ser.WriteFixedBytes(recipient, 32);
        ser.WriteU64(amount);
        var data = ser.ToArray();

        var des = new BcsDeserializer(data);
        var readSender = des.ReadFixedBytes(32);
        var readRecipient = des.ReadFixedBytes(32);
        var readAmount = des.ReadU64();
        des.CheckEnd();

        Assert.Equal(sender, readSender);
        Assert.Equal(recipient, readRecipient);
        Assert.Equal(amount, readAmount);
    }

    [Fact]
    public void NestedVectors()
    {
        var values = new List<List<byte>>
        {
            new() { 1, 2 },
            new() { 3, 4, 5 }
        };

        var ser = new BcsSerializer();
        ser.WriteVector(values, (s, inner) =>
            s.WriteVector(inner, (s2, v) => s2.WriteU8(v)));
        var data = ser.ToArray();

        var des = new BcsDeserializer(data);
        var result = des.ReadVector(d =>
            d.ReadVector(d2 => d2.ReadU8()));
        des.CheckEnd();

        Assert.Equal(values.Count, result.Count);
        for (var i = 0; i < values.Count; i++)
        {
            Assert.Equal(values[i], result[i]);
        }
    }

    #endregion

    #region Map Tests

    [Fact]
    public void WriteMapSortsKeys()
    {
        var entries = new Dictionary<string, uint>
        {
            { "zebra", 1 },
            { "apple", 2 },
            { "mango", 3 }
        };

        var ser = new BcsSerializer();
        ser.WriteMap(
            entries,
            (s, k) => s.WriteString(k),
            (s, v) => s.WriteU32(v)
        );

        // Deserialize and verify sorted order
        var des = new BcsDeserializer(ser.ToArray());
        var result = des.ReadMap(
            d => d.ReadString(),
            d => d.ReadU32()
        );
        des.CheckEnd();

        Assert.Equal(3, result.Count);
        Assert.Equal(2u, result["apple"]);
        Assert.Equal(3u, result["mango"]);
        Assert.Equal(1u, result["zebra"]);
    }

    [Fact]
    public void ReadMapValidatesSortedKeys()
    {
        // Create a map with keys NOT in sorted order: "b" then "a"
        var ser = new BcsSerializer();
        ser.WriteMapLength(2);
        ser.WriteString("b");  // key "b"
        ser.WriteU32(1);       // value 1
        ser.WriteString("a");  // key "a" - out of order!
        ser.WriteU32(2);       // value 2

        var des = new BcsDeserializer(ser.ToArray());
        var ex = Assert.Throws<BcsException>(() =>
            des.ReadMap(
                d => d.ReadString(),
                d => d.ReadU32()
            )
        );
        Assert.Equal(BcsErrorType.NonCanonicalMap, ex.ErrorType);
    }

    [Fact]
    public void ReadMapRejectsDuplicateKeys()
    {
        // Create a map with duplicate keys: "a" twice
        var ser = new BcsSerializer();
        ser.WriteMapLength(2);
        ser.WriteString("a");  // key "a"
        ser.WriteU32(1);       // value 1
        ser.WriteString("a");  // key "a" again - duplicate!
        ser.WriteU32(2);       // value 2

        var des = new BcsDeserializer(ser.ToArray());
        var ex = Assert.Throws<BcsException>(() =>
            des.ReadMap(
                d => d.ReadString(),
                d => d.ReadU32()
            )
        );
        Assert.Equal(BcsErrorType.DuplicateMapKey, ex.ErrorType);
    }

    [Fact]
    public void MapRoundTrip()
    {
        var original = new Dictionary<uint, string>
        {
            { 100, "hundred" },
            { 1, "one" },
            { 50, "fifty" }
        };

        var ser = new BcsSerializer();
        ser.WriteMap(
            original,
            (s, k) => s.WriteU32(k),
            (s, v) => s.WriteString(v)
        );

        var des = new BcsDeserializer(ser.ToArray());
        var result = des.ReadMap(
            d => d.ReadU32(),
            d => d.ReadString()
        );
        des.CheckEnd();

        Assert.Equal(original.Count, result.Count);
        foreach (var kvp in original)
        {
            Assert.Equal(kvp.Value, result[kvp.Key]);
        }
    }

    #endregion
}
