// C# BCS E2E Test Runner
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;

class BcsSerializer {
    private List<byte> buffer = new List<byte>();
    
    public void WriteBool(bool v) => buffer.Add((byte)(v ? 1 : 0));
    public void WriteU8(byte v) => buffer.Add(v);
    public void WriteU16(ushort v) { WriteU8((byte)(v & 0xFF)); WriteU8((byte)((v >> 8) & 0xFF)); }
    public void WriteU32(uint v) { for (int i = 0; i < 4; i++) WriteU8((byte)((v >> (i * 8)) & 0xFF)); }
    public void WriteU64(ulong v) { for (int i = 0; i < 8; i++) WriteU8((byte)((v >> (i * 8)) & 0xFF)); }
    public void WriteU128(byte[] v) { buffer.AddRange(v); }
    public void WriteI8(sbyte v) => WriteU8((byte)v);
    public void WriteI16(short v) => WriteU16((ushort)v);
    public void WriteI32(int v) => WriteU32((uint)v);
    public void WriteI64(long v) => WriteU64((ulong)v);
    public void WriteI128(byte[] v) => WriteU128(v);
    
    public void WriteUleb128(uint v) {
        do {
            byte b = (byte)(v & 0x7F);
            v >>= 7;
            if (v != 0) b |= 0x80;
            WriteU8(b);
        } while (v != 0);
    }
    
    public void WriteString(string s) {
        var bytes = Encoding.UTF8.GetBytes(s);
        WriteUleb128((uint)bytes.Length);
        buffer.AddRange(bytes);
    }
    
    public void WriteBytes(byte[] bytes) {
        WriteUleb128((uint)bytes.Length);
        buffer.AddRange(bytes);
    }
    
    public void WriteFixedBytes(byte[] bytes) => buffer.AddRange(bytes);
    
    public byte[] ToBytes() => buffer.ToArray();
}

class BcsDeserializer {
    private byte[] data;
    private int offset = 0;
    
    public BcsDeserializer(byte[] data) { this.data = data; }
    
    public bool ReadBool() {
        var b = ReadU8();
        if (b != 0 && b != 1) throw new Exception("Invalid bool");
        return b == 1;
    }
    
    public byte ReadU8() {
        if (offset >= data.Length) throw new Exception("EOF");
        return data[offset++];
    }
    
    public ushort ReadU16() {
        if (offset + 2 > data.Length) throw new Exception("EOF");
        var v = (ushort)(data[offset] | (data[offset + 1] << 8));
        offset += 2;
        return v;
    }
    
    public uint ReadU32() {
        if (offset + 4 > data.Length) throw new Exception("EOF");
        uint v = 0;
        for (int i = 0; i < 4; i++) v |= (uint)data[offset + i] << (i * 8);
        offset += 4;
        return v;
    }
    
    public ulong ReadU64() {
        if (offset + 8 > data.Length) throw new Exception("EOF");
        ulong v = 0;
        for (int i = 0; i < 8; i++) v |= (ulong)data[offset + i] << (i * 8);
        offset += 8;
        return v;
    }
    
    public byte[] ReadU128() {
        if (offset + 16 > data.Length) throw new Exception("EOF");
        var v = new byte[16];
        Array.Copy(data, offset, v, 0, 16);
        offset += 16;
        return v;
    }
    
    public sbyte ReadI8() => (sbyte)ReadU8();
    public short ReadI16() => (short)ReadU16();
    public int ReadI32() => (int)ReadU32();
    public long ReadI64() => (long)ReadU64();
    public byte[] ReadI128() => ReadU128();
    
    public uint ReadUleb128() {
        uint v = 0;
        int shift = 0;
        while (true) {
            var b = ReadU8();
            v |= (uint)(b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift += 7;
        }
        return v;
    }
    
    public string ReadString() {
        var len = ReadUleb128();
        if (offset + len > data.Length) throw new Exception("EOF");
        var s = Encoding.UTF8.GetString(data, offset, (int)len);
        offset += (int)len;
        return s;
    }
    
    public byte[] ReadBytes() {
        var len = ReadUleb128();
        if (offset + len > data.Length) throw new Exception("EOF");
        var bytes = new byte[len];
        Array.Copy(data, offset, bytes, 0, (int)len);
        offset += (int)len;
        return bytes;
    }
    
    public byte[] ReadFixedBytes(int len) {
        if (offset + len > data.Length) throw new Exception("EOF");
        var bytes = new byte[len];
        Array.Copy(data, offset, bytes, 0, len);
        offset += len;
        return bytes;
    }
    
    public void CheckEnd() {
        if (offset != data.Length) throw new Exception("Remaining input");
    }
}

class Program {
    static byte[] HexToBytes(string hex) {
        var bytes = new byte[hex.Length / 2];
        for (int i = 0; i < bytes.Length; i++)
            bytes[i] = Convert.ToByte(hex.Substring(i * 2, 2), 16);
        return bytes;
    }
    
    static string BytesToHex(byte[] bytes) {
        var sb = new StringBuilder();
        foreach (var b in bytes) sb.AppendFormat("{0:x2}", b);
        return sb.ToString();
    }
    
    static (string hex, string? error) ProcessTestCase(string type, byte[] data, JsonElement value) {
        try {
            var d = new BcsDeserializer(data);
            var s = new BcsSerializer();
            
            switch (type) {
                case "bool": { var v = d.ReadBool(); d.CheckEnd(); s.WriteBool(v); break; }
                case "u8": { var v = d.ReadU8(); d.CheckEnd(); s.WriteU8(v); break; }
                case "u16": { var v = d.ReadU16(); d.CheckEnd(); s.WriteU16(v); break; }
                case "u32": { var v = d.ReadU32(); d.CheckEnd(); s.WriteU32(v); break; }
                case "u64": { var v = d.ReadU64(); d.CheckEnd(); s.WriteU64(v); break; }
                case "u128": { var v = d.ReadU128(); d.CheckEnd(); s.WriteU128(v); break; }
                case "i8": { var v = d.ReadI8(); d.CheckEnd(); s.WriteI8(v); break; }
                case "i16": { var v = d.ReadI16(); d.CheckEnd(); s.WriteI16(v); break; }
                case "i32": { var v = d.ReadI32(); d.CheckEnd(); s.WriteI32(v); break; }
                case "i64": { var v = d.ReadI64(); d.CheckEnd(); s.WriteI64(v); break; }
                case "i128": { var v = d.ReadI128(); d.CheckEnd(); s.WriteI128(v); break; }
                case "string": { var v = d.ReadString(); d.CheckEnd(); s.WriteString(v); break; }
                case "bytes": { var v = d.ReadBytes(); d.CheckEnd(); s.WriteBytes(v); break; }
                case "fixed_bytes_32": { var v = d.ReadFixedBytes(32); d.CheckEnd(); s.WriteFixedBytes(v); break; }
                case "option<u8>": {
                    var has = d.ReadBool(); s.WriteBool(has);
                    if (has) { var v = d.ReadU8(); s.WriteU8(v); }
                    d.CheckEnd(); break;
                }
                case "option<u64>": {
                    var has = d.ReadBool(); s.WriteBool(has);
                    if (has) { var v = d.ReadU64(); s.WriteU64(v); }
                    d.CheckEnd(); break;
                }
                case "option<bool>": {
                    var has = d.ReadBool(); s.WriteBool(has);
                    if (has) { var v = d.ReadBool(); s.WriteBool(v); }
                    d.CheckEnd(); break;
                }
                case "option<string>": {
                    var has = d.ReadBool(); s.WriteBool(has);
                    if (has) { var v = d.ReadString(); s.WriteString(v); }
                    d.CheckEnd(); break;
                }
                case "vector<u8>": {
                    var len = d.ReadUleb128(); s.WriteUleb128(len);
                    for (uint i = 0; i < len; i++) { var v = d.ReadU8(); s.WriteU8(v); }
                    d.CheckEnd(); break;
                }
                case "vector<u64>": {
                    var len = d.ReadUleb128(); s.WriteUleb128(len);
                    for (uint i = 0; i < len; i++) { var v = d.ReadU64(); s.WriteU64(v); }
                    d.CheckEnd(); break;
                }
                case "vector<bool>": {
                    var len = d.ReadUleb128(); s.WriteUleb128(len);
                    for (uint i = 0; i < len; i++) { var v = d.ReadBool(); s.WriteBool(v); }
                    d.CheckEnd(); break;
                }
                case "vector<string>": {
                    var len = d.ReadUleb128(); s.WriteUleb128(len);
                    for (uint i = 0; i < len; i++) { var v = d.ReadString(); s.WriteString(v); }
                    d.CheckEnd(); break;
                }
                case "vector<vector<u8>>": {
                    var outerLen = d.ReadUleb128(); s.WriteUleb128(outerLen);
                    for (uint i = 0; i < outerLen; i++) {
                        var innerLen = d.ReadUleb128(); s.WriteUleb128(innerLen);
                        for (uint j = 0; j < innerLen; j++) { var v = d.ReadU8(); s.WriteU8(v); }
                    }
                    d.CheckEnd(); break;
                }
                case "vector<option<u8>>": {
                    var len = d.ReadUleb128(); s.WriteUleb128(len);
                    for (uint i = 0; i < len; i++) {
                        var has = d.ReadBool(); s.WriteBool(has);
                        if (has) { var v = d.ReadU8(); s.WriteU8(v); }
                    }
                    d.CheckEnd(); break;
                }
                case "struct": {
                    if (value.TryGetProperty("fields", out var fields)) {
                        foreach (var field in fields.EnumerateArray()) {
                            var fieldType = field.GetProperty("type").GetString();
                            switch (fieldType) {
                                case "u8": s.WriteU8(d.ReadU8()); break;
                                case "u64": s.WriteU64(d.ReadU64()); break;
                                case "string": s.WriteString(d.ReadString()); break;
                                case "fixed_bytes_32": s.WriteFixedBytes(d.ReadFixedBytes(32)); break;
                            }
                        }
                    }
                    d.CheckEnd(); break;
                }
                case "map<u8,u8>": {
                    var len = d.ReadUleb128(); s.WriteUleb128(len);
                    for (uint i = 0; i < len; i++) { s.WriteU8(d.ReadU8()); s.WriteU8(d.ReadU8()); }
                    d.CheckEnd(); break;
                }
                case "map<string,u64>": {
                    var len = d.ReadUleb128(); s.WriteUleb128(len);
                    for (uint i = 0; i < len; i++) { s.WriteString(d.ReadString()); s.WriteU64(d.ReadU64()); }
                    d.CheckEnd(); break;
                }
                case "tuple<u8,u64>": {
                    s.WriteU8(d.ReadU8()); s.WriteU64(d.ReadU64());
                    d.CheckEnd(); break;
                }
                default: return ("", $"Unknown type: {type}");
            }
            
            return (BytesToHex(s.ToBytes()), null);
        } catch (Exception e) {
            return ("", e.Message);
        }
    }
    
    // Benchmark support
    static (double avg, double min, double max, double p50, double p95) ComputeStats(long[] times) {
        if (times.Length == 0) return (0, 0, 0, 0, 0);
        Array.Sort(times);
        var n = times.Length;
        var sum = times.Sum();
        return (
            (double)sum / n,
            times[0],
            times[n-1],
            times[n/2],
            times[(int)(n * 0.95)]
        );
    }
    
    static object? GenerateBenchValue(JsonElement bc) {
        if (bc.TryGetProperty("value", out var v) && v.ValueKind != JsonValueKind.Null) return v;
        var length = bc.TryGetProperty("length", out var len) ? len.GetInt32() : 10;
        var gen = bc.TryGetProperty("value_generator", out var g) ? g.GetString() : null;
        return gen switch {
            "repeat_char" => new string((bc.TryGetProperty("char", out var c) ? c.GetString()?[0] : 'a') ?? 'a', length),
            "sequential_bytes" or "sequential_u8" => Enumerable.Range(0, length).Select(i => i % 256).ToArray(),
            "sequential_u64" => Enumerable.Range(0, length).Select(i => i.ToString()).ToArray(),
            "address_bytes" => Enumerable.Repeat(0, 31).Concat(new[] { 1 }).ToArray(),
            _ => bc.TryGetProperty("value", out var vv) ? (object?)vv : null
        };
    }
    
    static void SerializeBenchValue(BcsSerializer s, string type, object? value) {
        switch (type) {
            case "bool": s.WriteBool(value is bool bv && bv); break;
            case "u8": s.WriteU8((byte)(value is int i ? i : 0)); break;
            case "u16": s.WriteU16((ushort)(value is int ii ? ii : 0)); break;
            case "u32": s.WriteU32((uint)(value is long l ? l : 0)); break;
            case "u64":
                ulong v64 = value is string sv ? ulong.Parse(sv) : (value is long lv ? (ulong)lv : 0);
                s.WriteU64(v64);
                break;
            case "string": s.WriteString(value?.ToString() ?? ""); break;
            case "bytes": case "vector<u8>":
                var arr = value as int[] ?? Array.Empty<int>();
                s.WriteUleb128((uint)arr.Length);
                foreach (var b in arr) s.WriteU8((byte)b);
                break;
            case "vector<u64>":
                var arr64 = value as string[] ?? Array.Empty<string>();
                s.WriteUleb128((uint)arr64.Length);
                foreach (var x in arr64) s.WriteU64(ulong.Parse(x));
                break;
            case "vector<string>":
                var arrS = value as string[] ?? Array.Empty<string>();
                s.WriteUleb128((uint)arrS.Length);
                foreach (var x in arrS) s.WriteString(x);
                break;
        }
    }
    
    static void DeserializeBenchValue(BcsDeserializer d, string type) {
        switch (type) {
            case "bool": d.ReadBool(); break;
            case "u8": d.ReadU8(); break;
            case "u16": d.ReadU16(); break;
            case "u32": d.ReadU32(); break;
            case "u64": d.ReadU64(); break;
            case "string": d.ReadString(); break;
            case "bytes": case "vector<u8>":
                var len = d.ReadUleb128();
                for (uint i = 0; i < len; i++) d.ReadU8();
                break;
            case "vector<u64>":
                var len64 = d.ReadUleb128();
                for (uint i = 0; i < len64; i++) d.ReadU64();
                break;
            case "vector<string>":
                var lenS = d.ReadUleb128();
                for (uint i = 0; i < lenS; i++) d.ReadString();
                break;
        }
    }
    
    static void RunBenchmarks(JsonElement root) {
        var defaultIterations = 1000;
        var warmup = 10;
        if (root.TryGetProperty("config", out var cfg)) {
            if (cfg.TryGetProperty("default_iterations", out var di)) defaultIterations = di.GetInt32();
            if (cfg.TryGetProperty("warmup_iterations", out var wi)) warmup = wi.GetInt32();
        }
        
        Console.WriteLine("{");
        Console.WriteLine("  \"version\": \"1.0.0\",");
        Console.WriteLine("  \"description\": \"C# benchmark results\",");
        Console.WriteLine("  \"benchmarks\": [");
        
        var firstResult = true;
        if (root.TryGetProperty("scenarios", out var scenarios)) {
            foreach (var scenario in scenarios.EnumerateObject()) {
                if (!scenario.Value.TryGetProperty("benchmarks", out var benchmarks)) continue;
                
                foreach (var bc in benchmarks.EnumerateArray()) {
                    var name = bc.GetProperty("name").GetString() ?? "";
                    var type = bc.GetProperty("type").GetString() ?? "";
                    var iterations = bc.TryGetProperty("iterations", out var it) ? it.GetInt32() : defaultIterations;
                    
                    if (!firstResult) Console.WriteLine(",");
                    firstResult = false;
                    
                    try {
                        var value = GenerateBenchValue(bc);
                        
                        // Serialize to get bytes
                        var ser = new BcsSerializer();
                        SerializeBenchValue(ser, type, value);
                        var bcsBytes = ser.ToBytes();
                        
                        // Warmup
                        for (int i = 0; i < warmup; i++) {
                            var ws = new BcsSerializer();
                            SerializeBenchValue(ws, type, value);
                            ws.ToBytes();
                        }
                        
                        // Benchmark serialize
                        var sw = new System.Diagnostics.Stopwatch();
                        var serTimes = new long[iterations];
                        for (int i = 0; i < iterations; i++) {
                            sw.Restart();
                            var bs = new BcsSerializer();
                            SerializeBenchValue(bs, type, value);
                            bs.ToBytes();
                            sw.Stop();
                            serTimes[i] = sw.ElapsedTicks * 1000000000L / System.Diagnostics.Stopwatch.Frequency;
                        }
                        
                        // Warmup deserialize
                        for (int i = 0; i < warmup; i++) {
                            var wd = new BcsDeserializer(bcsBytes);
                            DeserializeBenchValue(wd, type);
                        }
                        
                        // Benchmark deserialize
                        var deTimes = new long[iterations];
                        for (int i = 0; i < iterations; i++) {
                            sw.Restart();
                            var bd = new BcsDeserializer(bcsBytes);
                            DeserializeBenchValue(bd, type);
                            sw.Stop();
                            deTimes[i] = sw.ElapsedTicks * 1000000000L / System.Diagnostics.Stopwatch.Frequency;
                        }
                        
                        var serStats = ComputeStats(serTimes);
                        var deStats = ComputeStats(deTimes);
                        
                        Console.Write($"    {{\"name\": \"{name}\", \"type\": \"{type}\", \"iterations\": {iterations}, ");
                        Console.Write($"\"serialize_avg_ns\": {serStats.avg}, \"serialize_min_ns\": {serStats.min}, \"serialize_max_ns\": {serStats.max}, ");
                        Console.Write($"\"serialize_p50_ns\": {serStats.p50}, \"serialize_p95_ns\": {serStats.p95}, ");
                        Console.Write($"\"deserialize_avg_ns\": {deStats.avg}, \"deserialize_min_ns\": {deStats.min}, \"deserialize_max_ns\": {deStats.max}, ");
                        Console.Write($"\"deserialize_p50_ns\": {deStats.p50}, \"deserialize_p95_ns\": {deStats.p95}, ");
                        Console.Write($"\"throughput_serialize_ops_sec\": {(serStats.avg > 0 ? 1e9/serStats.avg : 0)}, ");
                        Console.Write($"\"throughput_deserialize_ops_sec\": {(deStats.avg > 0 ? 1e9/deStats.avg : 0)}}}");
                    } catch (Exception e) {
                        Console.Write($"    {{\"name\": \"{name}\", \"type\": \"{type}\", \"iterations\": {iterations}, \"error\": \"{e.Message}\"}}");
                    }
                }
            }
        }
        
        Console.WriteLine();
        Console.WriteLine("  ]");
        Console.WriteLine("}");
    }
    
    static void Main(string[] args) {
        var benchmarkMode = args.Contains("--benchmark");
        var input = Console.In.ReadToEnd();
        var doc = JsonDocument.Parse(input);
        var root = doc.RootElement;
        
        if (benchmarkMode) {
            RunBenchmarks(root);
            return;
        }
        
        Console.WriteLine("{");
        Console.WriteLine("  \"version\": \"1.0.0\",");
        Console.WriteLine("  \"description\": \"C# roundtrip results\",");
        
        string[] categories = { "primitives", "strings", "bytes", "options", "vectors", "structs", "complex" };
        
        for (int ci = 0; ci < categories.Length; ci++) {
            var category = categories[ci];
            Console.WriteLine($"  \"{category}\": [");
            
            if (root.TryGetProperty(category, out var tests)) {
                var testArray = tests.EnumerateArray().ToArray();
                for (int ti = 0; ti < testArray.Length; ti++) {
                    var test = testArray[ti];
                    var name = test.GetProperty("name").GetString() ?? "";
                    var type = test.GetProperty("type").GetString() ?? "";
                    var bcsHex = test.GetProperty("bcs_hex").GetString() ?? "";
                    var value = test.GetProperty("value");
                    
                    var data = HexToBytes(bcsHex);
                    var (resultHex, error) = ProcessTestCase(type, data, value);
                    
                    var valueJson = value.GetRawText();
                    var comma = ti < testArray.Length - 1 ? "," : "";
                    
                    if (error != null) {
                        Console.WriteLine($"    {{\"name\": \"{name}\", \"type\": \"{type}\", \"bcs_hex\": \"\", \"value\": {valueJson}, \"error\": \"{error}\"}}{comma}");
                    } else {
                        Console.WriteLine($"    {{\"name\": \"{name}\", \"type\": \"{type}\", \"bcs_hex\": \"{resultHex}\", \"value\": {valueJson}}}{comma}");
                    }
                }
            }
            
            var catComma = ci < categories.Length - 1 ? "," : "";
            Console.WriteLine($"  ]{catComma}");
        }
        
        Console.WriteLine("}");
    }
}
