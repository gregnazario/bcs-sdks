#!/usr/bin/env dotnet-script
// C# BCS E2E Test Runner
//
// Reads test vectors from stdin, performs roundtrip serialization,
// and outputs results to stdout.
//
// Run with: dotnet script csharp_runner.cs

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;

// Simple BCS implementation for roundtrip testing
class BcsSerializer
{
    private readonly MemoryStream _buffer = new();
    
    public BcsSerializer WriteBool(bool v) { _buffer.WriteByte(v ? (byte)1 : (byte)0); return this; }
    public BcsSerializer WriteU8(byte v) { _buffer.WriteByte(v); return this; }
    public BcsSerializer WriteU16(ushort v) {
        _buffer.WriteByte((byte)(v & 0xFF));
        _buffer.WriteByte((byte)((v >> 8) & 0xFF));
        return this;
    }
    public BcsSerializer WriteU32(uint v) {
        for (int i = 0; i < 4; i++) _buffer.WriteByte((byte)((v >> (i * 8)) & 0xFF));
        return this;
    }
    public BcsSerializer WriteU64(ulong v) {
        for (int i = 0; i < 8; i++) _buffer.WriteByte((byte)((v >> (i * 8)) & 0xFF));
        return this;
    }
    public BcsSerializer WriteU128(byte[] bytes) { _buffer.Write(bytes); return this; }
    public BcsSerializer WriteI8(sbyte v) => WriteU8((byte)v);
    public BcsSerializer WriteI16(short v) => WriteU16((ushort)v);
    public BcsSerializer WriteI32(int v) => WriteU32((uint)v);
    public BcsSerializer WriteI64(long v) => WriteU64((ulong)v);
    public BcsSerializer WriteI128(byte[] bytes) => WriteU128(bytes);
    
    public BcsSerializer WriteUleb128(uint v) {
        do {
            byte b = (byte)(v & 0x7F);
            v >>= 7;
            if (v != 0) b |= 0x80;
            _buffer.WriteByte(b);
        } while (v != 0);
        return this;
    }
    
    public BcsSerializer WriteString(string s) {
        var bytes = Encoding.UTF8.GetBytes(s);
        WriteUleb128((uint)bytes.Length);
        _buffer.Write(bytes);
        return this;
    }
    
    public BcsSerializer WriteBytes(byte[] bytes) {
        WriteUleb128((uint)bytes.Length);
        _buffer.Write(bytes);
        return this;
    }
    
    public BcsSerializer WriteFixedBytes(byte[] bytes) { _buffer.Write(bytes); return this; }
    public byte[] ToArray() => _buffer.ToArray();
}

class BcsDeserializer
{
    private readonly byte[] _data;
    private int _offset = 0;
    
    public BcsDeserializer(byte[] data) => _data = data;
    
    public bool ReadBool() {
        if (_offset >= _data.Length) throw new Exception("EOF");
        byte b = _data[_offset++];
        if (b != 0 && b != 1) throw new Exception("Invalid bool");
        return b == 1;
    }
    
    public byte ReadU8() {
        if (_offset >= _data.Length) throw new Exception("EOF");
        return _data[_offset++];
    }
    
    public ushort ReadU16() {
        if (_offset + 2 > _data.Length) throw new Exception("EOF");
        ushort v = (ushort)(_data[_offset] | (_data[_offset + 1] << 8));
        _offset += 2;
        return v;
    }
    
    public uint ReadU32() {
        if (_offset + 4 > _data.Length) throw new Exception("EOF");
        uint v = 0;
        for (int i = 0; i < 4; i++) v |= (uint)_data[_offset + i] << (i * 8);
        _offset += 4;
        return v;
    }
    
    public ulong ReadU64() {
        if (_offset + 8 > _data.Length) throw new Exception("EOF");
        ulong v = 0;
        for (int i = 0; i < 8; i++) v |= (ulong)_data[_offset + i] << (i * 8);
        _offset += 8;
        return v;
    }
    
    public byte[] ReadU128() {
        if (_offset + 16 > _data.Length) throw new Exception("EOF");
        var bytes = _data[_offset..(_offset + 16)];
        _offset += 16;
        return bytes;
    }
    
    public sbyte ReadI8() => (sbyte)ReadU8();
    public short ReadI16() => (short)ReadU16();
    public int ReadI32() => (int)ReadU32();
    public long ReadI64() => (long)ReadU64();
    public byte[] ReadI128() => ReadU128();
    
    public uint ReadUleb128() {
        uint value = 0;
        int shift = 0;
        while (true) {
            if (_offset >= _data.Length) throw new Exception("EOF");
            byte b = _data[_offset++];
            value |= (uint)(b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift += 7;
        }
        return value;
    }
    
    public string ReadString() {
        uint len = ReadUleb128();
        if (_offset + len > _data.Length) throw new Exception("EOF");
        var s = Encoding.UTF8.GetString(_data, _offset, (int)len);
        _offset += (int)len;
        return s;
    }
    
    public byte[] ReadBytes() {
        uint len = ReadUleb128();
        if (_offset + len > _data.Length) throw new Exception("EOF");
        var bytes = _data[_offset..(_offset + (int)len)];
        _offset += (int)len;
        return bytes;
    }
    
    public byte[] ReadFixedBytes(int len) {
        if (_offset + len > _data.Length) throw new Exception("EOF");
        var bytes = _data[_offset..(_offset + len)];
        _offset += len;
        return bytes;
    }
    
    public void CheckEnd() {
        if (_offset != _data.Length) throw new Exception("Remaining input");
    }
}

static byte[] HexToBytes(string hex) {
    var bytes = new byte[hex.Length / 2];
    for (int i = 0; i < bytes.Length; i++)
        bytes[i] = Convert.ToByte(hex.Substring(i * 2, 2), 16);
    return bytes;
}

static string BytesToHex(byte[] bytes) => BitConverter.ToString(bytes).Replace("-", "").ToLower();

static Dictionary<string, object> ProcessTestCase(JsonElement tc) {
    string name = tc.GetProperty("name").GetString()!;
    string type = tc.GetProperty("type").GetString()!;
    string bcsHex = tc.GetProperty("bcs_hex").GetString()!;
    JsonElement value = tc.TryGetProperty("value", out var v) ? v : default;
    
    try {
        var data = HexToBytes(bcsHex);
        string resultHex = type switch {
            "bool" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadBool(); d.CheckEnd(); return new BcsSerializer().WriteBool(x).ToArray(); }),
            "u8" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadU8(); d.CheckEnd(); return new BcsSerializer().WriteU8(x).ToArray(); }),
            "u16" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadU16(); d.CheckEnd(); return new BcsSerializer().WriteU16(x).ToArray(); }),
            "u32" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadU32(); d.CheckEnd(); return new BcsSerializer().WriteU32(x).ToArray(); }),
            "u64" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadU64(); d.CheckEnd(); return new BcsSerializer().WriteU64(x).ToArray(); }),
            "u128" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadU128(); d.CheckEnd(); return new BcsSerializer().WriteU128(x).ToArray(); }),
            "i8" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadI8(); d.CheckEnd(); return new BcsSerializer().WriteI8(x).ToArray(); }),
            "i16" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadI16(); d.CheckEnd(); return new BcsSerializer().WriteI16(x).ToArray(); }),
            "i32" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadI32(); d.CheckEnd(); return new BcsSerializer().WriteI32(x).ToArray(); }),
            "i64" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadI64(); d.CheckEnd(); return new BcsSerializer().WriteI64(x).ToArray(); }),
            "i128" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadI128(); d.CheckEnd(); return new BcsSerializer().WriteI128(x).ToArray(); }),
            "string" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadString(); d.CheckEnd(); return new BcsSerializer().WriteString(x).ToArray(); }),
            "bytes" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadBytes(); d.CheckEnd(); return new BcsSerializer().WriteBytes(x).ToArray(); }),
            "fixed_bytes_32" => Process(() => { var d = new BcsDeserializer(data); var x = d.ReadFixedBytes(32); d.CheckEnd(); return new BcsSerializer().WriteFixedBytes(x).ToArray(); }),
            "option<u8>" => Process(() => { var d = new BcsDeserializer(data); bool hasVal = d.ReadBool(); var s = new BcsSerializer().WriteBool(hasVal); if (hasVal) s.WriteU8(d.ReadU8()); d.CheckEnd(); return s.ToArray(); }),
            "option<u64>" => Process(() => { var d = new BcsDeserializer(data); bool hasVal = d.ReadBool(); var s = new BcsSerializer().WriteBool(hasVal); if (hasVal) s.WriteU64(d.ReadU64()); d.CheckEnd(); return s.ToArray(); }),
            "option<bool>" => Process(() => { var d = new BcsDeserializer(data); bool hasVal = d.ReadBool(); var s = new BcsSerializer().WriteBool(hasVal); if (hasVal) s.WriteBool(d.ReadBool()); d.CheckEnd(); return s.ToArray(); }),
            "option<string>" => Process(() => { var d = new BcsDeserializer(data); bool hasVal = d.ReadBool(); var s = new BcsSerializer().WriteBool(hasVal); if (hasVal) s.WriteString(d.ReadString()); d.CheckEnd(); return s.ToArray(); }),
            "vector<u8>" => ProcessVector(data, d => d.ReadU8(), (s, x) => s.WriteU8(x)),
            "vector<u64>" => ProcessVector(data, d => d.ReadU64(), (s, x) => s.WriteU64(x)),
            "vector<bool>" => ProcessVector(data, d => d.ReadBool(), (s, x) => s.WriteBool(x)),
            "vector<vector<u8>>" => ProcessNestedVector(data),
            "vector<string>" => ProcessVector(data, d => d.ReadString(), (s, x) => s.WriteString(x)),
            "struct" => ProcessStruct(data, value),
            "map<u8,u8>" => ProcessMap(data, d => d.ReadU8(), d => d.ReadU8(), (s, k) => s.WriteU8(k), (s, v) => s.WriteU8(v)),
            "map<string,u64>" => ProcessMap(data, d => d.ReadString(), d => d.ReadU64(), (s, k) => s.WriteString(k), (s, v) => s.WriteU64(v)),
            "tuple<u8,u64>" => Process(() => { var d = new BcsDeserializer(data); var a = d.ReadU8(); var b = d.ReadU64(); d.CheckEnd(); return new BcsSerializer().WriteU8(a).WriteU64(b).ToArray(); }),
            "vector<option<u8>>" => ProcessVectorOption(data),
            _ => throw new Exception($"Unknown type: {type}")
        };
        
        return new Dictionary<string, object> { ["name"] = name, ["type"] = type, ["bcs_hex"] = resultHex, ["value"] = value };
    } catch (Exception e) {
        return new Dictionary<string, object> { ["name"] = name, ["type"] = type, ["bcs_hex"] = "", ["value"] = value, ["error"] = e.Message };
    }
}

static string Process(Func<byte[]> fn) => BytesToHex(fn());

static string ProcessVector<T>(byte[] data, Func<BcsDeserializer, T> read, Action<BcsSerializer, T> write) {
    var d = new BcsDeserializer(data);
    uint len = d.ReadUleb128();
    var vals = new List<T>();
    for (uint i = 0; i < len; i++) vals.Add(read(d));
    d.CheckEnd();
    var s = new BcsSerializer().WriteUleb128((uint)vals.Count);
    foreach (var v in vals) write(s, v);
    return BytesToHex(s.ToArray());
}

static string ProcessNestedVector(byte[] data) {
    var d = new BcsDeserializer(data);
    uint outerLen = d.ReadUleb128();
    var outer = new List<List<byte>>();
    for (uint i = 0; i < outerLen; i++) {
        uint innerLen = d.ReadUleb128();
        var inner = new List<byte>();
        for (uint j = 0; j < innerLen; j++) inner.Add(d.ReadU8());
        outer.Add(inner);
    }
    d.CheckEnd();
    var s = new BcsSerializer().WriteUleb128((uint)outer.Count);
    foreach (var inner in outer) {
        s.WriteUleb128((uint)inner.Count);
        foreach (var v in inner) s.WriteU8(v);
    }
    return BytesToHex(s.ToArray());
}

static string ProcessStruct(byte[] data, JsonElement value) {
    var d = new BcsDeserializer(data);
    var s = new BcsSerializer();
    foreach (var field in value.GetProperty("fields").EnumerateArray()) {
        switch (field.GetProperty("type").GetString()) {
            case "u8": s.WriteU8(d.ReadU8()); break;
            case "u64": s.WriteU64(d.ReadU64()); break;
            case "string": s.WriteString(d.ReadString()); break;
            case "fixed_bytes_32": s.WriteFixedBytes(d.ReadFixedBytes(32)); break;
        }
    }
    d.CheckEnd();
    return BytesToHex(s.ToArray());
}

static string ProcessMap<K, V>(byte[] data, Func<BcsDeserializer, K> readK, Func<BcsDeserializer, V> readV, Action<BcsSerializer, K> writeK, Action<BcsSerializer, V> writeV) {
    var d = new BcsDeserializer(data);
    uint len = d.ReadUleb128();
    var pairs = new List<(K, V)>();
    for (uint i = 0; i < len; i++) pairs.Add((readK(d), readV(d)));
    d.CheckEnd();
    var s = new BcsSerializer().WriteUleb128((uint)pairs.Count);
    foreach (var (k, v) in pairs) { writeK(s, k); writeV(s, v); }
    return BytesToHex(s.ToArray());
}

static string ProcessVectorOption(byte[] data) {
    var d = new BcsDeserializer(data);
    uint len = d.ReadUleb128();
    var vals = new List<byte?>();
    for (uint i = 0; i < len; i++) {
        bool hasVal = d.ReadBool();
        vals.Add(hasVal ? d.ReadU8() : null);
    }
    d.CheckEnd();
    var s = new BcsSerializer().WriteUleb128((uint)vals.Count);
    foreach (var v in vals) {
        s.WriteBool(v.HasValue);
        if (v.HasValue) s.WriteU8(v.Value);
    }
    return BytesToHex(s.ToArray());
}

// Main
var input = Console.In.ReadToEnd();
var vectors = JsonSerializer.Deserialize<JsonElement>(input);

var output = new Dictionary<string, object> {
    ["version"] = vectors.TryGetProperty("version", out var ver) ? ver.GetString()! : "1.0.0",
    ["description"] = "C# roundtrip results"
};

foreach (var category in new[] { "primitives", "strings", "bytes", "options", "vectors", "structs", "complex" }) {
    if (vectors.TryGetProperty(category, out var arr)) {
        output[category] = arr.EnumerateArray().Select(ProcessTestCase).ToList();
    } else {
        output[category] = new List<Dictionary<string, object>>();
    }
}

Console.WriteLine(JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true }));
