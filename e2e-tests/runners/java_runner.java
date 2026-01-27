///usr/bin/env java --source 11 "$0" "$@"; exit $?
// Java BCS E2E Test Runner (Java 11+)
//
// Reads test vectors from stdin, performs roundtrip serialization,
// and outputs results to stdout.

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class java_runner {
    
    static class BcsSerializer {
        private final ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        
        BcsSerializer writeBool(boolean v) { buffer.write(v ? 1 : 0); return this; }
        BcsSerializer writeU8(int v) { buffer.write(v & 0xFF); return this; }
        BcsSerializer writeU16(int v) {
            buffer.write(v & 0xFF);
            buffer.write((v >> 8) & 0xFF);
            return this;
        }
        BcsSerializer writeU32(long v) {
            for (int i = 0; i < 4; i++) buffer.write((int)((v >> (i * 8)) & 0xFF));
            return this;
        }
        BcsSerializer writeU64(long v) {
            for (int i = 0; i < 8; i++) buffer.write((int)((v >> (i * 8)) & 0xFF));
            return this;
        }
        BcsSerializer writeU128(byte[] bytes) { buffer.write(bytes, 0, bytes.length); return this; }
        BcsSerializer writeI8(int v) { buffer.write(v & 0xFF); return this; }
        BcsSerializer writeI16(int v) { return writeU16(v & 0xFFFF); }
        BcsSerializer writeI32(int v) { return writeU32(Integer.toUnsignedLong(v)); }
        BcsSerializer writeI64(long v) { return writeU64(v); }
        BcsSerializer writeI128(byte[] bytes) { return writeU128(bytes); }
        
        BcsSerializer writeUleb128(int v) {
            do {
                int b = v & 0x7F;
                v >>>= 7;
                if (v != 0) b |= 0x80;
                buffer.write(b);
            } while (v != 0);
            return this;
        }
        
        BcsSerializer writeString(String s) {
            byte[] bytes = s.getBytes(StandardCharsets.UTF_8);
            writeUleb128(bytes.length);
            buffer.write(bytes, 0, bytes.length);
            return this;
        }
        
        BcsSerializer writeBytes(byte[] bytes) {
            writeUleb128(bytes.length);
            buffer.write(bytes, 0, bytes.length);
            return this;
        }
        
        BcsSerializer writeFixedBytes(byte[] bytes) { buffer.write(bytes, 0, bytes.length); return this; }
        byte[] toBytes() { return buffer.toByteArray(); }
    }
    
    static class BcsDeserializer {
        private final byte[] data;
        private int offset = 0;
        
        BcsDeserializer(byte[] data) { this.data = data; }
        
        boolean readBool() throws Exception {
            if (offset >= data.length) throw new Exception("EOF");
            int b = data[offset++] & 0xFF;
            if (b != 0 && b != 1) throw new Exception("Invalid bool");
            return b == 1;
        }
        
        int readU8() throws Exception {
            if (offset >= data.length) throw new Exception("EOF");
            return data[offset++] & 0xFF;
        }
        
        int readU16() throws Exception {
            if (offset + 2 > data.length) throw new Exception("EOF");
            int v = (data[offset] & 0xFF) | ((data[offset + 1] & 0xFF) << 8);
            offset += 2;
            return v;
        }
        
        long readU32() throws Exception {
            if (offset + 4 > data.length) throw new Exception("EOF");
            long v = 0;
            for (int i = 0; i < 4; i++) v |= ((long)(data[offset + i] & 0xFF)) << (i * 8);
            offset += 4;
            return v;
        }
        
        long readU64() throws Exception {
            if (offset + 8 > data.length) throw new Exception("EOF");
            long v = 0;
            for (int i = 0; i < 8; i++) v |= ((long)(data[offset + i] & 0xFF)) << (i * 8);
            offset += 8;
            return v;
        }
        
        byte[] readU128() throws Exception {
            if (offset + 16 > data.length) throw new Exception("EOF");
            byte[] bytes = Arrays.copyOfRange(data, offset, offset + 16);
            offset += 16;
            return bytes;
        }
        
        int readI8() throws Exception {
            int u = readU8();
            return u < 128 ? u : u - 256;
        }
        
        int readI16() throws Exception {
            int u = readU16();
            return u < 32768 ? u : u - 65536;
        }
        
        int readI32() throws Exception {
            long u = readU32();
            return (int)u;
        }
        
        long readI64() throws Exception { return readU64(); }
        byte[] readI128() throws Exception { return readU128(); }
        
        int readUleb128() throws Exception {
            int value = 0, shift = 0;
            while (true) {
                if (offset >= data.length) throw new Exception("EOF");
                int b = data[offset++] & 0xFF;
                value |= (b & 0x7F) << shift;
                if ((b & 0x80) == 0) break;
                shift += 7;
            }
            return value;
        }
        
        String readString() throws Exception {
            int len = readUleb128();
            if (offset + len > data.length) throw new Exception("EOF");
            String s = new String(data, offset, len, StandardCharsets.UTF_8);
            offset += len;
            return s;
        }
        
        byte[] readBytes() throws Exception {
            int len = readUleb128();
            if (offset + len > data.length) throw new Exception("EOF");
            byte[] bytes = Arrays.copyOfRange(data, offset, offset + len);
            offset += len;
            return bytes;
        }
        
        byte[] readFixedBytes(int len) throws Exception {
            if (offset + len > data.length) throw new Exception("EOF");
            byte[] bytes = Arrays.copyOfRange(data, offset, offset + len);
            offset += len;
            return bytes;
        }
        
        void checkEnd() throws Exception {
            if (offset != data.length) throw new Exception("Remaining input");
        }
    }
    
    static byte[] hexToBytes(String hex) {
        byte[] bytes = new byte[hex.length() / 2];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte)Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        }
        return bytes;
    }
    
    static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) sb.append(String.format("%02x", b & 0xFF));
        return sb.toString();
    }
    
    @SuppressWarnings("unchecked")
    static Map<String, Object> processTestCase(Map<String, Object> tc) {
        String name = (String)tc.get("name");
        String type = (String)tc.get("type");
        String bcsHex = (String)tc.get("bcs_hex");
        
        try {
            byte[] data = hexToBytes(bcsHex);
            String resultHex;
            
            switch (type) {
                case "bool": {
                    BcsDeserializer d = new BcsDeserializer(data); boolean v = d.readBool(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeBool(v).toBytes());
                    break;
                }
                case "u8": {
                    BcsDeserializer d = new BcsDeserializer(data); int v = d.readU8(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeU8(v).toBytes());
                    break;
                }
                case "u16": {
                    BcsDeserializer d = new BcsDeserializer(data); int v = d.readU16(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeU16(v).toBytes());
                    break;
                }
                case "u32": {
                    BcsDeserializer d = new BcsDeserializer(data); long v = d.readU32(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeU32(v).toBytes());
                    break;
                }
                case "u64": {
                    BcsDeserializer d = new BcsDeserializer(data); long v = d.readU64(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeU64(v).toBytes());
                    break;
                }
                case "u128": {
                    BcsDeserializer d = new BcsDeserializer(data); byte[] v = d.readU128(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeU128(v).toBytes());
                    break;
                }
                case "i8": {
                    BcsDeserializer d = new BcsDeserializer(data); int v = d.readI8(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeI8(v).toBytes());
                    break;
                }
                case "i16": {
                    BcsDeserializer d = new BcsDeserializer(data); int v = d.readI16(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeI16(v).toBytes());
                    break;
                }
                case "i32": {
                    BcsDeserializer d = new BcsDeserializer(data); int v = d.readI32(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeI32(v).toBytes());
                    break;
                }
                case "i64": {
                    BcsDeserializer d = new BcsDeserializer(data); long v = d.readI64(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeI64(v).toBytes());
                    break;
                }
                case "i128": {
                    BcsDeserializer d = new BcsDeserializer(data); byte[] v = d.readI128(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeI128(v).toBytes());
                    break;
                }
                case "string": {
                    BcsDeserializer d = new BcsDeserializer(data); String v = d.readString(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeString(v).toBytes());
                    break;
                }
                case "bytes": {
                    BcsDeserializer d = new BcsDeserializer(data); byte[] v = d.readBytes(); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeBytes(v).toBytes());
                    break;
                }
                case "fixed_bytes_32": {
                    BcsDeserializer d = new BcsDeserializer(data); byte[] v = d.readFixedBytes(32); d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeFixedBytes(v).toBytes());
                    break;
                }
                case "option<u8>": {
                    BcsDeserializer d = new BcsDeserializer(data); boolean hasVal = d.readBool();
                    BcsSerializer s = new BcsSerializer().writeBool(hasVal);
                    if (hasVal) s.writeU8(d.readU8());
                    d.checkEnd(); resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "option<u64>": {
                    BcsDeserializer d = new BcsDeserializer(data); boolean hasVal = d.readBool();
                    BcsSerializer s = new BcsSerializer().writeBool(hasVal);
                    if (hasVal) s.writeU64(d.readU64());
                    d.checkEnd(); resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "option<bool>": {
                    BcsDeserializer d = new BcsDeserializer(data); boolean hasVal = d.readBool();
                    BcsSerializer s = new BcsSerializer().writeBool(hasVal);
                    if (hasVal) s.writeBool(d.readBool());
                    d.checkEnd(); resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "option<string>": {
                    BcsDeserializer d = new BcsDeserializer(data); boolean hasVal = d.readBool();
                    BcsSerializer s = new BcsSerializer().writeBool(hasVal);
                    if (hasVal) s.writeString(d.readString());
                    d.checkEnd(); resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "vector<u8>": {
                    BcsDeserializer d = new BcsDeserializer(data); int len = d.readUleb128();
                    List<Integer> vals = new ArrayList<>(); for (int i = 0; i < len; i++) vals.add(d.readU8());
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(vals.size());
                    for (int v : vals) s.writeU8(v);
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "vector<u64>": {
                    BcsDeserializer d = new BcsDeserializer(data); int len = d.readUleb128();
                    List<Long> vals = new ArrayList<>(); for (int i = 0; i < len; i++) vals.add(d.readU64());
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(vals.size());
                    for (long v : vals) s.writeU64(v);
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "vector<bool>": {
                    BcsDeserializer d = new BcsDeserializer(data); int len = d.readUleb128();
                    List<Boolean> vals = new ArrayList<>(); for (int i = 0; i < len; i++) vals.add(d.readBool());
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(vals.size());
                    for (boolean v : vals) s.writeBool(v);
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "vector<vector<u8>>": {
                    BcsDeserializer d = new BcsDeserializer(data); int outerLen = d.readUleb128();
                    List<List<Integer>> outer = new ArrayList<>();
                    for (int i = 0; i < outerLen; i++) {
                        int innerLen = d.readUleb128();
                        List<Integer> inner = new ArrayList<>();
                        for (int j = 0; j < innerLen; j++) inner.add(d.readU8());
                        outer.add(inner);
                    }
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(outer.size());
                    for (List<Integer> inner : outer) {
                        s.writeUleb128(inner.size());
                        for (int v : inner) s.writeU8(v);
                    }
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "vector<string>": {
                    BcsDeserializer d = new BcsDeserializer(data); int len = d.readUleb128();
                    List<String> vals = new ArrayList<>(); for (int i = 0; i < len; i++) vals.add(d.readString());
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(vals.size());
                    for (String v : vals) s.writeString(v);
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "struct": {
                    Map<String, Object> value = (Map<String, Object>)tc.get("value");
                    List<Map<String, Object>> fields = (List<Map<String, Object>>)value.get("fields");
                    BcsDeserializer d = new BcsDeserializer(data);
                    BcsSerializer s = new BcsSerializer();
                    for (Map<String, Object> field : fields) {
                        String fieldType = (String)field.get("type");
                        if ("u8".equals(fieldType)) s.writeU8(d.readU8());
                        else if ("u64".equals(fieldType)) s.writeU64(d.readU64());
                        else if ("string".equals(fieldType)) s.writeString(d.readString());
                        else if ("fixed_bytes_32".equals(fieldType)) s.writeFixedBytes(d.readFixedBytes(32));
                    }
                    d.checkEnd(); resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "map<u8,u8>": {
                    BcsDeserializer d = new BcsDeserializer(data); int len = d.readUleb128();
                    List<int[]> pairs = new ArrayList<>();
                    for (int i = 0; i < len; i++) pairs.add(new int[]{d.readU8(), d.readU8()});
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(pairs.size());
                    for (int[] p : pairs) { s.writeU8(p[0]); s.writeU8(p[1]); }
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "map<string,u64>": {
                    BcsDeserializer d = new BcsDeserializer(data); int len = d.readUleb128();
                    List<Object[]> pairs = new ArrayList<>();
                    for (int i = 0; i < len; i++) pairs.add(new Object[]{d.readString(), d.readU64()});
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(pairs.size());
                    for (Object[] p : pairs) { s.writeString((String)p[0]); s.writeU64((Long)p[1]); }
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                case "tuple<u8,u64>": {
                    BcsDeserializer d = new BcsDeserializer(data);
                    int a = d.readU8(); long b = d.readU64();
                    d.checkEnd();
                    resultHex = bytesToHex(new BcsSerializer().writeU8(a).writeU64(b).toBytes());
                    break;
                }
                case "vector<option<u8>>": {
                    BcsDeserializer d = new BcsDeserializer(data); int len = d.readUleb128();
                    List<Integer> vals = new ArrayList<>();
                    for (int i = 0; i < len; i++) {
                        boolean hasVal = d.readBool();
                        vals.add(hasVal ? d.readU8() : null);
                    }
                    d.checkEnd();
                    BcsSerializer s = new BcsSerializer().writeUleb128(vals.size());
                    for (Integer v : vals) {
                        s.writeBool(v != null);
                        if (v != null) s.writeU8(v);
                    }
                    resultHex = bytesToHex(s.toBytes());
                    break;
                }
                default: {
                    Map<String, Object> result = new LinkedHashMap<>();
                    result.put("name", name); result.put("type", type); result.put("bcs_hex", "");
                    result.put("value", tc.get("value")); result.put("error", "Unknown type: " + type);
                    return result;
                }
            }
            
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("name", name);
            result.put("type", type);
            result.put("bcs_hex", resultHex);
            result.put("value", tc.get("value"));
            return result;
        } catch (Exception e) {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("name", name);
            result.put("type", type);
            result.put("bcs_hex", "");
            result.put("value", tc.get("value"));
            result.put("error", e.getMessage());
            return result;
        }
    }
    
    // Simple JSON parsing (no external dependencies)
    static Object parseJson(String json) {
        return new JsonParser(json).parseValue();
    }
    
    static class JsonParser {
        private final String json;
        private int idx = 0;
        JsonParser(String json) { this.json = json; }
        
        void skipWhitespace() { while (idx < json.length() && Character.isWhitespace(json.charAt(idx))) idx++; }
        
        Object parseValue() {
            skipWhitespace();
            char c = json.charAt(idx);
            if (c == '"') return parseString();
            if (c == '{') return parseObject();
            if (c == '[') return parseArray();
            if (c == 't') { idx += 4; return true; }
            if (c == 'f') { idx += 5; return false; }
            if (c == 'n') { idx += 4; return null; }
            return parseNumber();
        }
        
        String parseString() {
            idx++; // skip "
            StringBuilder sb = new StringBuilder();
            while (json.charAt(idx) != '"') {
                if (json.charAt(idx) == '\\') {
                    idx++;
                    char ec = json.charAt(idx);
                    if (ec == '"' || ec == '\\' || ec == '/') sb.append(ec);
                    else if (ec == 'n') sb.append('\n');
                    else if (ec == 'r') sb.append('\r');
                    else if (ec == 't') sb.append('\t');
                    else if (ec == 'u') { sb.append((char)Integer.parseInt(json.substring(idx + 1, idx + 5), 16)); idx += 4; }
                } else sb.append(json.charAt(idx));
                idx++;
            }
            idx++; // skip "
            return sb.toString();
        }
        
        Map<String, Object> parseObject() {
            idx++; // skip {
            Map<String, Object> map = new LinkedHashMap<>();
            skipWhitespace();
            if (json.charAt(idx) != '}') {
                while (true) {
                    skipWhitespace();
                    String key = parseString();
                    skipWhitespace();
                    idx++; // skip :
                    map.put(key, parseValue());
                    skipWhitespace();
                    if (json.charAt(idx) == '}') break;
                    idx++; // skip ,
                }
            }
            idx++; // skip }
            return map;
        }
        
        List<Object> parseArray() {
            idx++; // skip [
            List<Object> list = new ArrayList<>();
            skipWhitespace();
            if (json.charAt(idx) != ']') {
                while (true) {
                    list.add(parseValue());
                    skipWhitespace();
                    if (json.charAt(idx) == ']') break;
                    idx++; // skip ,
                }
            }
            idx++; // skip ]
            return list;
        }
        
        Object parseNumber() {
            int start = idx;
            if (json.charAt(idx) == '-') idx++;
            while (idx < json.length() && (Character.isDigit(json.charAt(idx)) || json.charAt(idx) == '.' || json.charAt(idx) == 'e' || json.charAt(idx) == 'E' || json.charAt(idx) == '+' || json.charAt(idx) == '-')) idx++;
            String num = json.substring(start, idx);
            if (num.contains(".") || num.contains("e") || num.contains("E")) return Double.parseDouble(num);
            return Long.parseLong(num);
        }
    }
    
    static String toJson(Object obj, int indent) {
        String spaces = repeat("  ", indent);
        String nextSpaces = repeat("  ", indent + 1);
        if (obj == null) return "null";
        if (obj instanceof Boolean) return obj.toString();
        if (obj instanceof Number) return obj.toString();
        if (obj instanceof String) {
            String s = (String)obj;
            return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + "\"";
        }
        if (obj instanceof List) {
            List<?> list = (List<?>)obj;
            if (list.isEmpty()) return "[]";
            StringBuilder sb = new StringBuilder("[\n");
            for (int i = 0; i < list.size(); i++) {
                sb.append(nextSpaces).append(toJson(list.get(i), indent + 1));
                if (i < list.size() - 1) sb.append(",");
                sb.append("\n");
            }
            return sb.append(spaces).append("]").toString();
        }
        if (obj instanceof Map) {
            Map<?, ?> map = (Map<?, ?>)obj;
            if (map.isEmpty()) return "{}";
            StringBuilder sb = new StringBuilder("{\n");
            List<?> entries = new ArrayList<>(map.entrySet());
            for (int i = 0; i < entries.size(); i++) {
                Map.Entry<?, ?> e = (Map.Entry<?, ?>)entries.get(i);
                sb.append(nextSpaces).append("\"").append(e.getKey()).append("\": ").append(toJson(e.getValue(), indent + 1));
                if (i < entries.size() - 1) sb.append(",");
                sb.append("\n");
            }
            return sb.append(spaces).append("}").toString();
        }
        return "null";
    }
    
    static String repeat(String s, int n) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < n; i++) sb.append(s);
        return sb.toString();
    }
    
    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) sb.append(line).append("\n");
        String input = sb.toString();
        
        Map<String, Object> vectors = (Map<String, Object>)parseJson(input);
        
        Map<String, Object> output = new LinkedHashMap<>();
        output.put("version", vectors.getOrDefault("version", "1.0.0"));
        output.put("description", "Java roundtrip results");
        
        String[] categories = {"primitives", "strings", "bytes", "options", "vectors", "structs", "complex"};
        for (String category : categories) {
            List<Map<String, Object>> list = (List<Map<String, Object>>)vectors.getOrDefault(category, new ArrayList<>());
            List<Map<String, Object>> results = new ArrayList<>();
            for (Map<String, Object> tc : list) {
                results.add(processTestCase(tc));
            }
            output.put(category, results);
        }
        
        System.out.println(toJson(output, 0));
    }
}
