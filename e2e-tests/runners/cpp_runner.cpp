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

int main() {
    std::string input((std::istreambuf_iterator<char>(std::cin)), std::istreambuf_iterator<char>());
    
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
