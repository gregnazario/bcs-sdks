// C++ BCS E2E Test Runner
// Compile: g++ -std=c++17 -O2 -o cpp_runner cpp_runner.cpp

#include <cstdint>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <string>
#include <vector>
#include <map>
#include <optional>
#include <stdexcept>
#include <chrono>
#include <algorithm>

// Simple JSON helpers
std::string escapeJson(const std::string& s) {
    std::string out;
    for (char c : s) {
        switch (c) {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default: out += c;
        }
    }
    return out;
}

// BCS Serializer
class BcsSerializer {
    std::vector<uint8_t> buffer;
public:
    void writeBool(bool v) { buffer.push_back(v ? 1 : 0); }
    void writeU8(uint8_t v) { buffer.push_back(v); }
    void writeU16(uint16_t v) { buffer.push_back(v & 0xFF); buffer.push_back((v >> 8) & 0xFF); }
    void writeU32(uint32_t v) { for (int i = 0; i < 4; i++) buffer.push_back((v >> (i * 8)) & 0xFF); }
    void writeU64(uint64_t v) { for (int i = 0; i < 8; i++) buffer.push_back((v >> (i * 8)) & 0xFF); }
    void writeU128(const std::vector<uint8_t>& bytes) { buffer.insert(buffer.end(), bytes.begin(), bytes.end()); }
    void writeI8(int8_t v) { writeU8(static_cast<uint8_t>(v)); }
    void writeI16(int16_t v) { writeU16(static_cast<uint16_t>(v)); }
    void writeI32(int32_t v) { writeU32(static_cast<uint32_t>(v)); }
    void writeI64(int64_t v) { writeU64(static_cast<uint64_t>(v)); }
    void writeI128(const std::vector<uint8_t>& bytes) { writeU128(bytes); }
    
    void writeU128fromString(const std::string& s) {
        // Simple u128 from decimal string - store as 16 bytes little-endian
        uint8_t bytes[16] = {0};
        // Very simple implementation - parse and store
        unsigned __int128 val = 0;
        for (char c : s) {
            if (c >= '0' && c <= '9') {
                val = val * 10 + (c - '0');
            }
        }
        for (int i = 0; i < 16; i++) {
            bytes[i] = (val >> (i * 8)) & 0xFF;
        }
        buffer.insert(buffer.end(), bytes, bytes + 16);
    }
    
    void writeI128fromString(const std::string& s) {
        // Simple i128 from decimal string
        bool neg = !s.empty() && s[0] == '-';
        std::string abs_s = neg ? s.substr(1) : s;
        unsigned __int128 val = 0;
        for (char c : abs_s) {
            if (c >= '0' && c <= '9') {
                val = val * 10 + (c - '0');
            }
        }
        __int128 sval = neg ? -(__int128)val : (__int128)val;
        uint8_t bytes[16];
        for (int i = 0; i < 16; i++) {
            bytes[i] = (sval >> (i * 8)) & 0xFF;
        }
        buffer.insert(buffer.end(), bytes, bytes + 16);
    }
    
    void writeUleb128(uint32_t v) {
        do {
            uint8_t b = v & 0x7F;
            v >>= 7;
            if (v != 0) b |= 0x80;
            buffer.push_back(b);
        } while (v != 0);
    }
    
    void writeString(const std::string& s) {
        writeUleb128(s.size());
        buffer.insert(buffer.end(), s.begin(), s.end());
    }
    
    void writeBytes(const std::vector<uint8_t>& bytes) {
        writeUleb128(bytes.size());
        buffer.insert(buffer.end(), bytes.begin(), bytes.end());
    }
    
    void writeFixedBytes(const std::vector<uint8_t>& bytes) {
        buffer.insert(buffer.end(), bytes.begin(), bytes.end());
    }
    
    const std::vector<uint8_t>& getBuffer() const { return buffer; }
    std::vector<uint8_t> toBytes() const { return buffer; }
};

// BCS Deserializer
class BcsDeserializer {
    const std::vector<uint8_t>& data;
    size_t offset = 0;
public:
    BcsDeserializer(const std::vector<uint8_t>& d) : data(d) {}
    
    bool readBool() {
        if (offset >= data.size()) throw std::runtime_error("EOF");
        uint8_t b = data[offset++];
        if (b != 0 && b != 1) throw std::runtime_error("Invalid bool");
        return b == 1;
    }
    
    uint8_t readU8() {
        if (offset >= data.size()) throw std::runtime_error("EOF");
        return data[offset++];
    }
    
    uint16_t readU16() {
        if (offset + 2 > data.size()) throw std::runtime_error("EOF");
        uint16_t v = data[offset] | (data[offset + 1] << 8);
        offset += 2;
        return v;
    }
    
    uint32_t readU32() {
        if (offset + 4 > data.size()) throw std::runtime_error("EOF");
        uint32_t v = 0;
        for (int i = 0; i < 4; i++) v |= static_cast<uint32_t>(data[offset + i]) << (i * 8);
        offset += 4;
        return v;
    }
    
    uint64_t readU64() {
        if (offset + 8 > data.size()) throw std::runtime_error("EOF");
        uint64_t v = 0;
        for (int i = 0; i < 8; i++) v |= static_cast<uint64_t>(data[offset + i]) << (i * 8);
        offset += 8;
        return v;
    }
    
    std::vector<uint8_t> readU128() {
        if (offset + 16 > data.size()) throw std::runtime_error("EOF");
        std::vector<uint8_t> bytes(data.begin() + offset, data.begin() + offset + 16);
        offset += 16;
        return bytes;
    }
    
    int8_t readI8() { return static_cast<int8_t>(readU8()); }
    int16_t readI16() { return static_cast<int16_t>(readU16()); }
    int32_t readI32() { return static_cast<int32_t>(readU32()); }
    int64_t readI64() { return static_cast<int64_t>(readU64()); }
    std::vector<uint8_t> readI128() { return readU128(); }
    
    uint32_t readUleb128() {
        uint32_t value = 0;
        int shift = 0;
        while (true) {
            if (offset >= data.size()) throw std::runtime_error("EOF");
            uint8_t b = data[offset++];
            value |= (b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift += 7;
        }
        return value;
    }
    
    std::string readString() {
        uint32_t len = readUleb128();
        if (offset + len > data.size()) throw std::runtime_error("EOF");
        std::string s(data.begin() + offset, data.begin() + offset + len);
        offset += len;
        return s;
    }
    
    std::vector<uint8_t> readBytes() {
        uint32_t len = readUleb128();
        if (offset + len > data.size()) throw std::runtime_error("EOF");
        std::vector<uint8_t> bytes(data.begin() + offset, data.begin() + offset + len);
        offset += len;
        return bytes;
    }
    
    std::vector<uint8_t> readFixedBytes(size_t len) {
        if (offset + len > data.size()) throw std::runtime_error("EOF");
        std::vector<uint8_t> bytes(data.begin() + offset, data.begin() + offset + len);
        offset += len;
        return bytes;
    }
    
    void checkEnd() {
        if (offset != data.size()) throw std::runtime_error("Remaining input");
    }
};

std::vector<uint8_t> hexToBytes(const std::string& hex) {
    std::vector<uint8_t> bytes;
    for (size_t i = 0; i < hex.size(); i += 2) {
        bytes.push_back(std::stoi(hex.substr(i, 2), nullptr, 16));
    }
    return bytes;
}

std::string bytesToHex(const std::vector<uint8_t>& bytes) {
    std::stringstream ss;
    for (uint8_t b : bytes) ss << std::hex << std::setfill('0') << std::setw(2) << (int)b;
    return ss.str();
}

// Simple JSON parsing - very minimal, just enough for our test vectors
class JsonParser {
    const std::string& json;
    size_t idx = 0;
    
    void skipWhitespace() { while (idx < json.size() && isspace(json[idx])) idx++; }
    
public:
    JsonParser(const std::string& j) : json(j) {}
    
    std::string parseString() {
        idx++; // skip "
        std::string s;
        while (json[idx] != '"') {
            if (json[idx] == '\\') {
                idx++;
                switch (json[idx]) {
                    case '"': s += '"'; break;
                    case '\\': s += '\\'; break;
                    case 'n': s += '\n'; break;
                    case 'r': s += '\r'; break;
                    case 't': s += '\t'; break;
                    case 'u': {
                        // Simple unicode escape - just handle ASCII range
                        idx++;
                        int code = std::stoi(json.substr(idx, 4), nullptr, 16);
                        if (code < 128) s += (char)code;
                        idx += 3;
                        break;
                    }
                }
            } else {
                s += json[idx];
            }
            idx++;
        }
        idx++; // skip "
        return s;
    }
    
    std::map<std::string, std::string> parseObject() {
        idx++; // skip {
        std::map<std::string, std::string> map;
        skipWhitespace();
        if (json[idx] != '}') {
            while (true) {
                skipWhitespace();
                std::string key = parseString();
                skipWhitespace();
                idx++; // skip :
                skipWhitespace();
                
                // Find value end
                size_t start = idx;
                int depth = 0;
                bool inString = false;
                while (true) {
                    if (json[idx] == '"' && (idx == 0 || json[idx-1] != '\\')) inString = !inString;
                    if (!inString) {
                        if (json[idx] == '{' || json[idx] == '[') depth++;
                        if (json[idx] == '}' || json[idx] == ']') depth--;
                        if (depth < 0 || (depth == 0 && json[idx] == ',')) break;
                    }
                    idx++;
                }
                map[key] = json.substr(start, idx - start);
                
                skipWhitespace();
                if (json[idx] == '}') break;
                idx++; // skip ,
            }
        }
        idx++; // skip }
        return map;
    }
    
    std::vector<std::map<std::string, std::string>> parseArray() {
        std::vector<std::map<std::string, std::string>> arr;
        idx++; // skip [
        skipWhitespace();
        if (json[idx] != ']') {
            while (true) {
                skipWhitespace();
                if (json[idx] == '{') {
                    arr.push_back(parseObject());
                }
                skipWhitespace();
                if (json[idx] == ']') break;
                idx++; // skip ,
            }
        }
        idx++; // skip ]
        return arr;
    }
};

std::string processTestCase(const std::map<std::string, std::string>& tc) {
    std::string name = tc.count("name") ? JsonParser(tc.at("name")).parseString() : "";
    std::string type = tc.count("type") ? JsonParser(tc.at("type")).parseString() : "";
    std::string bcsHex = tc.count("bcs_hex") ? JsonParser(tc.at("bcs_hex")).parseString() : "";
    std::string value = tc.count("value") ? tc.at("value") : "null";
    
    try {
        auto data = hexToBytes(bcsHex);
        std::string resultHex;
        
        if (type == "bool") {
            BcsDeserializer d(data); bool v = d.readBool(); d.checkEnd();
            BcsSerializer s; s.writeBool(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "u8") {
            BcsDeserializer d(data); auto v = d.readU8(); d.checkEnd();
            BcsSerializer s; s.writeU8(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "u16") {
            BcsDeserializer d(data); auto v = d.readU16(); d.checkEnd();
            BcsSerializer s; s.writeU16(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "u32") {
            BcsDeserializer d(data); auto v = d.readU32(); d.checkEnd();
            BcsSerializer s; s.writeU32(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "u64") {
            BcsDeserializer d(data); auto v = d.readU64(); d.checkEnd();
            BcsSerializer s; s.writeU64(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "u128") {
            BcsDeserializer d(data); auto v = d.readU128(); d.checkEnd();
            BcsSerializer s; s.writeU128(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "i8") {
            BcsDeserializer d(data); auto v = d.readI8(); d.checkEnd();
            BcsSerializer s; s.writeI8(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "i16") {
            BcsDeserializer d(data); auto v = d.readI16(); d.checkEnd();
            BcsSerializer s; s.writeI16(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "i32") {
            BcsDeserializer d(data); auto v = d.readI32(); d.checkEnd();
            BcsSerializer s; s.writeI32(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "i64") {
            BcsDeserializer d(data); auto v = d.readI64(); d.checkEnd();
            BcsSerializer s; s.writeI64(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "i128") {
            BcsDeserializer d(data); auto v = d.readI128(); d.checkEnd();
            BcsSerializer s; s.writeI128(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "string") {
            BcsDeserializer d(data); auto v = d.readString(); d.checkEnd();
            BcsSerializer s; s.writeString(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "bytes") {
            BcsDeserializer d(data); auto v = d.readBytes(); d.checkEnd();
            BcsSerializer s; s.writeBytes(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "fixed_bytes_32") {
            BcsDeserializer d(data); auto v = d.readFixedBytes(32); d.checkEnd();
            BcsSerializer s; s.writeFixedBytes(v); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "option<u8>") {
            BcsDeserializer d(data); bool hasVal = d.readBool();
            BcsSerializer s; s.writeBool(hasVal);
            if (hasVal) s.writeU8(d.readU8());
            d.checkEnd(); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "option<u64>") {
            BcsDeserializer d(data); bool hasVal = d.readBool();
            BcsSerializer s; s.writeBool(hasVal);
            if (hasVal) s.writeU64(d.readU64());
            d.checkEnd(); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "option<bool>") {
            BcsDeserializer d(data); bool hasVal = d.readBool();
            BcsSerializer s; s.writeBool(hasVal);
            if (hasVal) s.writeBool(d.readBool());
            d.checkEnd(); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "option<string>") {
            BcsDeserializer d(data); bool hasVal = d.readBool();
            BcsSerializer s; s.writeBool(hasVal);
            if (hasVal) s.writeString(d.readString());
            d.checkEnd(); resultHex = bytesToHex(s.getBuffer());
        } else if (type == "vector<u8>") {
            BcsDeserializer d(data); auto len = d.readUleb128();
            std::vector<uint8_t> vals; for (uint32_t i = 0; i < len; i++) vals.push_back(d.readU8());
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(vals.size());
            for (auto v : vals) s.writeU8(v);
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "vector<u64>") {
            BcsDeserializer d(data); auto len = d.readUleb128();
            std::vector<uint64_t> vals; for (uint32_t i = 0; i < len; i++) vals.push_back(d.readU64());
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(vals.size());
            for (auto v : vals) s.writeU64(v);
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "vector<bool>") {
            BcsDeserializer d(data); auto len = d.readUleb128();
            std::vector<bool> vals; for (uint32_t i = 0; i < len; i++) vals.push_back(d.readBool());
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(vals.size());
            for (auto v : vals) s.writeBool(v);
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "vector<vector<u8>>") {
            BcsDeserializer d(data); auto outerLen = d.readUleb128();
            std::vector<std::vector<uint8_t>> outer;
            for (uint32_t i = 0; i < outerLen; i++) {
                auto innerLen = d.readUleb128();
                std::vector<uint8_t> inner;
                for (uint32_t j = 0; j < innerLen; j++) inner.push_back(d.readU8());
                outer.push_back(inner);
            }
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(outer.size());
            for (auto& inner : outer) { s.writeUleb128(inner.size()); for (auto v : inner) s.writeU8(v); }
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "vector<string>") {
            BcsDeserializer d(data); auto len = d.readUleb128();
            std::vector<std::string> vals; for (uint32_t i = 0; i < len; i++) vals.push_back(d.readString());
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(vals.size());
            for (auto& v : vals) s.writeString(v);
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "struct") {
            // Parse fields from value JSON - simplified
            BcsDeserializer d(data);
            BcsSerializer s;
            // Find fields array in value
            size_t pos = value.find("\"fields\"");
            if (pos != std::string::npos) {
                pos = value.find('[', pos);
                while (pos < value.size()) {
                    size_t typePos = value.find("\"type\"", pos);
                    if (typePos == std::string::npos) break;
                    size_t colonPos = value.find(':', typePos);
                    size_t quoteStart = value.find('"', colonPos);
                    size_t quoteEnd = value.find('"', quoteStart + 1);
                    std::string fieldType = value.substr(quoteStart + 1, quoteEnd - quoteStart - 1);
                    
                    if (fieldType == "u8") s.writeU8(d.readU8());
                    else if (fieldType == "u64") s.writeU64(d.readU64());
                    else if (fieldType == "string") s.writeString(d.readString());
                    else if (fieldType == "fixed_bytes_32") s.writeFixedBytes(d.readFixedBytes(32));
                    
                    pos = value.find('}', quoteEnd);
                    if (pos == std::string::npos) break;
                    pos++;
                }
            }
            d.checkEnd();
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "map<u8,u8>") {
            BcsDeserializer d(data); auto len = d.readUleb128();
            std::vector<std::pair<uint8_t, uint8_t>> pairs;
            for (uint32_t i = 0; i < len; i++) pairs.push_back({d.readU8(), d.readU8()});
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(pairs.size());
            for (auto& [k, v] : pairs) { s.writeU8(k); s.writeU8(v); }
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "map<string,u64>") {
            BcsDeserializer d(data); auto len = d.readUleb128();
            std::vector<std::pair<std::string, uint64_t>> pairs;
            for (uint32_t i = 0; i < len; i++) pairs.push_back({d.readString(), d.readU64()});
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(pairs.size());
            for (auto& [k, v] : pairs) { s.writeString(k); s.writeU64(v); }
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "tuple<u8,u64>") {
            BcsDeserializer d(data); auto a = d.readU8(); auto b = d.readU64(); d.checkEnd();
            BcsSerializer s; s.writeU8(a); s.writeU64(b);
            resultHex = bytesToHex(s.getBuffer());
        } else if (type == "vector<option<u8>>") {
            BcsDeserializer d(data); auto len = d.readUleb128();
            std::vector<std::optional<uint8_t>> vals;
            for (uint32_t i = 0; i < len; i++) {
                bool hasVal = d.readBool();
                vals.push_back(hasVal ? std::optional<uint8_t>(d.readU8()) : std::nullopt);
            }
            d.checkEnd();
            BcsSerializer s; s.writeUleb128(vals.size());
            for (auto& v : vals) { s.writeBool(v.has_value()); if (v) s.writeU8(*v); }
            resultHex = bytesToHex(s.getBuffer());
        } else {
            return "    {\n      \"name\": \"" + escapeJson(name) + "\",\n      \"type\": \"" + escapeJson(type) + "\",\n      \"bcs_hex\": \"\",\n      \"value\": " + value + ",\n      \"error\": \"Unknown type: " + type + "\"\n    }";
        }
        
        return "    {\n      \"name\": \"" + escapeJson(name) + "\",\n      \"type\": \"" + escapeJson(type) + "\",\n      \"bcs_hex\": \"" + resultHex + "\",\n      \"value\": " + value + "\n    }";
    } catch (const std::exception& e) {
        return "    {\n      \"name\": \"" + escapeJson(name) + "\",\n      \"type\": \"" + escapeJson(type) + "\",\n      \"bcs_hex\": \"\",\n      \"value\": " + value + ",\n      \"error\": \"" + escapeJson(e.what()) + "\"\n    }";
    }
}

// Benchmark support
struct BenchStats {
    double avg, min, max, p50, p95;
};

BenchStats computeStats(std::vector<long long>& times) {
    if (times.empty()) return {0, 0, 0, 0, 0};
    std::sort(times.begin(), times.end());
    size_t n = times.size();
    long long sum = 0;
    for (auto t : times) sum += t;
    return {
        (double)sum / n,
        (double)times[0],
        (double)times[n-1],
        (double)times[n/2],
        (double)times[(size_t)(n * 0.95)]
    };
}

std::string generateBenchValue(const std::map<std::string, std::string>& bc) {
    if (bc.count("value") && bc.at("value") != "null") return bc.at("value");
    int length = 10;
    if (bc.count("length")) {
        try { length = std::stoi(bc.at("length")); } catch (...) {}
    }
    std::string gen = bc.count("value_generator") ? bc.at("value_generator") : "";
    if (gen == "repeat_char") {
        std::string c = bc.count("char") ? bc.at("char") : "a";
        if (c.size() > 2) c = c.substr(1, c.size()-2); // Remove quotes
        std::string result = "\"";
        for (int i = 0; i < length; i++) result += c;
        result += "\"";
        return result;
    } else if (gen == "sequential_bytes" || gen == "sequential_u8") {
        std::string result = "[";
        for (int i = 0; i < length; i++) {
            if (i > 0) result += ",";
            result += std::to_string(i % 256);
        }
        result += "]";
        return result;
    } else if (gen == "sequential_u64") {
        std::string result = "[";
        for (int i = 0; i < length; i++) {
            if (i > 0) result += ",";
            result += "\"" + std::to_string(i) + "\"";
        }
        result += "]";
        return result;
    } else if (gen == "address_bytes") {
        std::string result = "[";
        for (int i = 0; i < 31; i++) result += "0,";
        result += "1]";
        return result;
    }
    return bc.count("value") ? bc.at("value") : "null";
}

void serializeBenchValue(BcsSerializer& s, const std::string& type, const std::string& valueJson) {
    if (type == "bool") {
        s.writeBool(valueJson == "true");
    } else if (type == "u8") {
        s.writeU8(std::stoi(valueJson));
    } else if (type == "u16") {
        s.writeU16(std::stoi(valueJson));
    } else if (type == "u32") {
        s.writeU32(std::stoul(valueJson));
    } else if (type == "u64") {
        std::string v = valueJson;
        if (v.front() == '"') v = v.substr(1, v.size()-2);
        s.writeU64(std::stoull(v));
    } else if (type == "u128") {
        std::string v = valueJson;
        if (v.front() == '"') v = v.substr(1, v.size()-2);
        s.writeU128fromString(v);
    } else if (type == "i8") {
        s.writeI8(std::stoi(valueJson));
    } else if (type == "i16") {
        s.writeI16(std::stoi(valueJson));
    } else if (type == "i32") {
        s.writeI32(std::stoi(valueJson));
    } else if (type == "i64") {
        std::string v = valueJson;
        if (v.front() == '"') v = v.substr(1, v.size()-2);
        s.writeI64(std::stoll(v));
    } else if (type == "i128") {
        std::string v = valueJson;
        if (v.front() == '"') v = v.substr(1, v.size()-2);
        s.writeI128fromString(v);
    } else if (type == "string") {
        std::string v = valueJson.substr(1, valueJson.size()-2);
        s.writeString(v);
    } else if (type == "bytes" || type == "vector<u8>") {
        JsonParser p(valueJson);
        auto arr = p.parseArray();
        s.writeUleb128(arr.size());
        for (auto& item : arr) s.writeU8(std::stoi(item));
    } else if (type == "fixed_bytes") {
        JsonParser p(valueJson);
        auto arr = p.parseArray();
        for (auto& item : arr) s.writeU8(std::stoi(item));
    } else if (type == "vector<u64>") {
        JsonParser p(valueJson);
        auto arr = p.parseArray();
        s.writeUleb128(arr.size());
        for (auto& item : arr) {
            std::string v = item;
            if (v.front() == '"') v = v.substr(1, v.size()-2);
            s.writeU64(std::stoull(v));
        }
    } else if (type == "vector<string>") {
        JsonParser p(valueJson);
        auto arr = p.parseArray();
        s.writeUleb128(arr.size());
        for (auto& item : arr) {
            std::string v = item.substr(1, item.size()-2);
            s.writeString(v);
        }
    }
}

void deserializeBenchValue(BcsDeserializer& d, const std::string& type) {
    if (type == "bool") { d.readBool(); }
    else if (type == "u8") { d.readU8(); }
    else if (type == "u16") { d.readU16(); }
    else if (type == "u32") { d.readU32(); }
    else if (type == "u64") { d.readU64(); }
    else if (type == "u128") { d.readU128(); }
    else if (type == "i8") { d.readI8(); }
    else if (type == "i16") { d.readI16(); }
    else if (type == "i32") { d.readI32(); }
    else if (type == "i64") { d.readI64(); }
    else if (type == "i128") { d.readI128(); }
    else if (type == "string") { d.readString(); }
    else if (type == "bytes" || type == "vector<u8>") {
        uint32_t len = d.readUleb128();
        for (uint32_t i = 0; i < len; i++) d.readU8();
    }
    else if (type == "fixed_bytes") {
        for (int i = 0; i < 32; i++) d.readU8();
    }
    else if (type == "vector<u64>") {
        uint32_t len = d.readUleb128();
        for (uint32_t i = 0; i < len; i++) d.readU64();
    }
    else if (type == "vector<string>") {
        uint32_t len = d.readUleb128();
        for (uint32_t i = 0; i < len; i++) d.readString();
    }
}

std::string runBenchmarks(const std::string& input) {
    JsonParser specParser(input);
    auto spec = specParser.parseObject();
    
    int defaultIterations = 1000, warmup = 10;
    if (spec.count("config")) {
        JsonParser cfgParser(spec["config"]);
        auto cfg = cfgParser.parseObject();
        if (cfg.count("default_iterations")) defaultIterations = std::stoi(cfg["default_iterations"]);
        if (cfg.count("warmup_iterations")) warmup = std::stoi(cfg["warmup_iterations"]);
    }
    
    std::ostringstream out;
    out << "{\n  \"version\": \"1.0.0\",\n  \"description\": \"C++ benchmark results\",\n  \"benchmarks\": [\n";
    
    bool firstResult = true;
    if (spec.count("scenarios")) {
        JsonParser scenParser(spec["scenarios"]);
        auto scenarios = scenParser.parseObject();
        
        for (auto& [catName, catJson] : scenarios) {
            JsonParser groupParser(catJson);
            auto group = groupParser.parseObject();
            if (!group.count("benchmarks")) continue;
            
            JsonParser benchParser(group["benchmarks"]);
            auto benchmarks = benchParser.parseArray();
            
            for (auto& bcJson : benchmarks) {
                JsonParser bcParser(bcJson);
                auto bc = bcParser.parseObject();
                
                std::string name = bc.count("name") ? bc["name"] : "";
                if (name.front() == '"') name = name.substr(1, name.size()-2);
                std::string type = bc.count("type") ? bc["type"] : "";
                if (type.front() == '"') type = type.substr(1, type.size()-2);
                int iterations = bc.count("iterations") ? std::stoi(bc["iterations"]) : defaultIterations;
                
                if (!firstResult) out << ",\n";
                firstResult = false;
                
                try {
                    std::string valueJson = generateBenchValue(bc);
                    
                    // Serialize to get bytes
                    BcsSerializer ser;
                    serializeBenchValue(ser, type, valueJson);
                    auto bcsBytes = ser.toBytes();
                    
                    // Warmup
                    for (int i = 0; i < warmup; i++) {
                        BcsSerializer ws;
                        serializeBenchValue(ws, type, valueJson);
                        ws.toBytes();
                    }
                    
                    // Benchmark serialize
                    std::vector<long long> serTimes(iterations);
                    for (int i = 0; i < iterations; i++) {
                        auto start = std::chrono::high_resolution_clock::now();
                        BcsSerializer bs;
                        serializeBenchValue(bs, type, valueJson);
                        bs.toBytes();
                        auto end = std::chrono::high_resolution_clock::now();
                        serTimes[i] = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
                    }
                    
                    // Warmup deserialize
                    for (int i = 0; i < warmup; i++) {
                        BcsDeserializer wd(bcsBytes);
                        deserializeBenchValue(wd, type);
                    }
                    
                    // Benchmark deserialize
                    std::vector<long long> deTimes(iterations);
                    for (int i = 0; i < iterations; i++) {
                        auto start = std::chrono::high_resolution_clock::now();
                        BcsDeserializer bd(bcsBytes);
                        deserializeBenchValue(bd, type);
                        auto end = std::chrono::high_resolution_clock::now();
                        deTimes[i] = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
                    }
                    
                    auto serStats = computeStats(serTimes);
                    auto deStats = computeStats(deTimes);
                    
                    out << "    {\"name\": \"" << escapeJson(name) << "\", \"type\": \"" << escapeJson(type) << "\", "
                        << "\"iterations\": " << iterations << ", "
                        << "\"serialize_avg_ns\": " << serStats.avg << ", "
                        << "\"serialize_min_ns\": " << serStats.min << ", "
                        << "\"serialize_max_ns\": " << serStats.max << ", "
                        << "\"serialize_p50_ns\": " << serStats.p50 << ", "
                        << "\"serialize_p95_ns\": " << serStats.p95 << ", "
                        << "\"deserialize_avg_ns\": " << deStats.avg << ", "
                        << "\"deserialize_min_ns\": " << deStats.min << ", "
                        << "\"deserialize_max_ns\": " << deStats.max << ", "
                        << "\"deserialize_p50_ns\": " << deStats.p50 << ", "
                        << "\"deserialize_p95_ns\": " << deStats.p95 << ", "
                        << "\"throughput_serialize_ops_sec\": " << (serStats.avg > 0 ? 1e9/serStats.avg : 0) << ", "
                        << "\"throughput_deserialize_ops_sec\": " << (deStats.avg > 0 ? 1e9/deStats.avg : 0) << "}";
                } catch (const std::exception& e) {
                    out << "    {\"name\": \"" << escapeJson(name) << "\", \"type\": \"" << escapeJson(type) << "\", "
                        << "\"iterations\": " << iterations << ", \"error\": \"" << escapeJson(e.what()) << "\"}";
                }
            }
        }
    }
    
    out << "\n  ]\n}\n";
    return out.str();
}

int main(int argc, char* argv[]) {
    // Check for benchmark flag
    bool benchmarkMode = false;
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "--benchmark") {
            benchmarkMode = true;
            break;
        }
    }
    
    std::string input((std::istreambuf_iterator<char>(std::cin)), std::istreambuf_iterator<char>());
    
    // Handle benchmark mode
    if (benchmarkMode) {
        std::cout << runBenchmarks(input);
        return 0;
    }
    
    JsonParser parser(input);
    auto vectors = parser.parseObject();
    
    std::cout << "{\n";
    std::cout << "  \"version\": \"1.0.0\",\n";
    std::cout << "  \"description\": \"C++ roundtrip results\",\n";
    
    std::vector<std::string> categories = {"primitives", "strings", "bytes", "options", "vectors", "structs", "complex"};
    for (size_t ci = 0; ci < categories.size(); ci++) {
        auto& cat = categories[ci];
        std::cout << "  \"" << cat << "\": [\n";
        
        if (vectors.count(cat)) {
            JsonParser arrParser(vectors[cat]);
            auto arr = arrParser.parseArray();
            for (size_t i = 0; i < arr.size(); i++) {
                std::cout << processTestCase(arr[i]);
                if (i < arr.size() - 1) std::cout << ",";
                std::cout << "\n";
            }
        }
        
        std::cout << "  ]";
        if (ci < categories.size() - 1) std::cout << ",";
        std::cout << "\n";
    }
    
    std::cout << "}\n";
    return 0;
}
