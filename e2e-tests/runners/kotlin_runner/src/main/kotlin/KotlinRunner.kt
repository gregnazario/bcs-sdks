import com.bcs.BcsSerializer
import com.bcs.BcsDeserializer

// Simple JSON parsing helpers
fun parseJsonObject(json: String): Map<String, Any?> {
    val result = mutableMapOf<String, Any?>()
    var pos = json.indexOf('{') + 1
    val end = json.lastIndexOf('}')
    if (pos <= 0 || end < 0) return result
    
    while (pos < end) {
        // Skip whitespace
        while (pos < end && json[pos].isWhitespace()) pos++
        if (pos >= end || json[pos] == '}') break
        
        // Read key
        if (json[pos] != '"') { pos++; continue }
        pos++
        val keyEnd = json.indexOf('"', pos)
        if (keyEnd < 0) break
        val key = json.substring(pos, keyEnd)
        pos = keyEnd + 1
        
        // Skip colon
        while (pos < end && (json[pos].isWhitespace() || json[pos] == ':')) pos++
        
        // Read value
        val (value, newPos) = parseJsonValue(json, pos, end)
        result[key] = value
        pos = newPos
        
        // Skip comma
        while (pos < end && (json[pos].isWhitespace() || json[pos] == ',')) pos++
    }
    
    return result
}

fun parseJsonArray(json: String, start: Int, end: Int): Pair<List<Any?>, Int> {
    val result = mutableListOf<Any?>()
    var pos = start + 1
    
    while (pos < end) {
        while (pos < end && json[pos].isWhitespace()) pos++
        if (pos >= end || json[pos] == ']') { pos++; break }
        
        val (value, newPos) = parseJsonValue(json, pos, end)
        result.add(value)
        pos = newPos
        
        while (pos < end && (json[pos].isWhitespace() || json[pos] == ',')) pos++
    }
    
    return Pair(result, pos)
}

fun parseJsonValue(json: String, start: Int, end: Int): Pair<Any?, Int> {
    var pos = start
    while (pos < end && json[pos].isWhitespace()) pos++
    
    return when {
        pos >= end -> Pair(null, pos)
        json[pos] == '"' -> {
            pos++
            val sb = StringBuilder()
            while (pos < end && json[pos] != '"') {
                if (json[pos] == '\\' && pos + 1 < end) {
                    pos++
                    when (json[pos]) {
                        'n' -> sb.append('\n')
                        'r' -> sb.append('\r')
                        't' -> sb.append('\t')
                        '"' -> sb.append('"')
                        '\\' -> sb.append('\\')
                        'u' -> {
                            if (pos + 4 < end) {
                                val code = json.substring(pos + 1, pos + 5).toIntOrNull(16) ?: 0
                                sb.append(code.toChar())
                                pos += 4
                            }
                        }
                        else -> sb.append(json[pos])
                    }
                } else {
                    sb.append(json[pos])
                }
                pos++
            }
            Pair(sb.toString(), pos + 1)
        }
        json[pos] == '{' -> {
            var depth = 1
            val objStart = pos
            pos++
            while (pos < end && depth > 0) {
                when (json[pos]) {
                    '{' -> depth++
                    '}' -> depth--
                    '"' -> {
                        pos++
                        while (pos < end && json[pos] != '"') {
                            if (json[pos] == '\\') pos++
                            pos++
                        }
                    }
                }
                pos++
            }
            Pair(parseJsonObject(json.substring(objStart, pos)), pos)
        }
        json[pos] == '[' -> parseJsonArray(json, pos, end)
        json.substring(pos).startsWith("true") -> Pair(true, pos + 4)
        json.substring(pos).startsWith("false") -> Pair(false, pos + 5)
        json.substring(pos).startsWith("null") -> Pair(null, pos + 4)
        json[pos] == '-' || json[pos].isDigit() -> {
            val numStart = pos
            if (json[pos] == '-') pos++
            while (pos < end && (json[pos].isDigit() || json[pos] == '.')) pos++
            val numStr = json.substring(numStart, pos)
            val value = if ('.' in numStr) numStr.toDoubleOrNull() else numStr.toLongOrNull()
            Pair(value, pos)
        }
        else -> Pair(null, pos + 1)
    }
}

fun hexToBytes(hex: String): ByteArray {
    return ByteArray(hex.length / 2) { i ->
        hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
    }
}

fun bytesToHex(bytes: ByteArray): String {
    return bytes.joinToString("") { "%02x".format(it) }
}

fun processTestCase(name: String, type: String, bcsHex: String, value: Any?): String {
    val data = hexToBytes(bcsHex)
    
    try {
        val d = BcsDeserializer(data)
        val s = BcsSerializer()
        
        when (type) {
            "bool" -> { val v = d.readBool(); d.checkEnd(); s.writeBool(v) }
            "u8" -> { val v = d.readU8(); d.checkEnd(); s.writeU8(v) }
            "u16" -> { val v = d.readU16(); d.checkEnd(); s.writeU16(v) }
            "u32" -> { val v = d.readU32(); d.checkEnd(); s.writeU32(v) }
            "u64" -> { val v = d.readU64(); d.checkEnd(); s.writeU64(v) }
            "i8" -> { val v = d.readI8(); d.checkEnd(); s.writeI8(v) }
            "i16" -> { val v = d.readI16(); d.checkEnd(); s.writeI16(v) }
            "i32" -> { val v = d.readI32(); d.checkEnd(); s.writeI32(v) }
            "i64" -> { val v = d.readI64(); d.checkEnd(); s.writeI64(v) }
            "u128", "i128" -> {
                val bytes = d.readFixedBytes(16)
                d.checkEnd()
                s.writeFixedBytes(bytes, 16)
            }
            "string" -> { val v = d.readString(); d.checkEnd(); s.writeString(v) }
            "bytes" -> { val v = d.readBytes(); d.checkEnd(); s.writeBytes(v) }
            "fixed_bytes_32" -> {
                val v = d.readFixedBytes(32)
                d.checkEnd()
                s.writeFixedBytes(v, 32)
            }
            "option<u8>" -> {
                val has = d.readBool()
                s.writeBool(has)
                if (has) { val v = d.readU8(); s.writeU8(v) }
                d.checkEnd()
            }
            "option<u64>" -> {
                val has = d.readBool()
                s.writeBool(has)
                if (has) { val v = d.readU64(); s.writeU64(v) }
                d.checkEnd()
            }
            "option<bool>" -> {
                val has = d.readBool()
                s.writeBool(has)
                if (has) { val v = d.readBool(); s.writeBool(v) }
                d.checkEnd()
            }
            "option<string>" -> {
                val has = d.readBool()
                s.writeBool(has)
                if (has) { val v = d.readString(); s.writeString(v) }
                d.checkEnd()
            }
            "vector<u8>" -> {
                val len = d.readUleb128().toInt()
                s.writeUleb128(len)
                repeat(len) { s.writeU8(d.readU8()) }
                d.checkEnd()
            }
            "vector<u64>" -> {
                val len = d.readUleb128().toInt()
                s.writeUleb128(len)
                repeat(len) { s.writeU64(d.readU64()) }
                d.checkEnd()
            }
            "vector<bool>" -> {
                val len = d.readUleb128().toInt()
                s.writeUleb128(len)
                repeat(len) { s.writeBool(d.readBool()) }
                d.checkEnd()
            }
            "vector<string>" -> {
                val len = d.readUleb128().toInt()
                s.writeUleb128(len)
                repeat(len) { s.writeString(d.readString()) }
                d.checkEnd()
            }
            "vector<vector<u8>>" -> {
                val outerLen = d.readUleb128().toInt()
                s.writeUleb128(outerLen)
                repeat(outerLen) {
                    val innerLen = d.readUleb128().toInt()
                    s.writeUleb128(innerLen)
                    repeat(innerLen) { s.writeU8(d.readU8()) }
                }
                d.checkEnd()
            }
            "vector<option<u8>>" -> {
                val len = d.readUleb128().toInt()
                s.writeUleb128(len)
                repeat(len) {
                    val has = d.readBool()
                    s.writeBool(has)
                    if (has) { s.writeU8(d.readU8()) }
                }
                d.checkEnd()
            }
            "struct" -> {
                @Suppress("UNCHECKED_CAST")
                val valueMap = value as? Map<String, Any?>
                val fields = valueMap?.get("fields") as? List<Map<String, Any?>> ?: emptyList()
                for (field in fields) {
                    when (field["type"]) {
                        "u8" -> s.writeU8(d.readU8())
                        "u64" -> s.writeU64(d.readU64())
                        "string" -> s.writeString(d.readString())
                        "fixed_bytes_32" -> s.writeFixedBytes(d.readFixedBytes(32), 32)
                    }
                }
                d.checkEnd()
            }
            "map<u8,u8>" -> {
                val len = d.readUleb128().toInt()
                s.writeUleb128(len)
                repeat(len) {
                    s.writeU8(d.readU8())
                    s.writeU8(d.readU8())
                }
                d.checkEnd()
            }
            "map<string,u64>" -> {
                val len = d.readUleb128().toInt()
                s.writeUleb128(len)
                repeat(len) {
                    s.writeString(d.readString())
                    s.writeU64(d.readU64())
                }
                d.checkEnd()
            }
            "tuple<u8,u64>" -> {
                s.writeU8(d.readU8())
                s.writeU64(d.readU64())
                d.checkEnd()
            }
            else -> return """{"name": "$name", "type": "$type", "bcs_hex": "", "value": null, "error": "Unknown type: $type"}"""
        }
        
        val resultHex = bytesToHex(s.toBytes())
        return """{"name": "$name", "type": "$type", "bcs_hex": "$resultHex", "value": ${toJson(value)}}"""
    } catch (e: Exception) {
        return """{"name": "$name", "type": "$type", "bcs_hex": "", "value": ${toJson(value)}, "error": "${e.message?.replace("\"", "\\\"")}"}"""
    }
}

fun toJson(value: Any?): String = when (value) {
    null -> "null"
    is Boolean -> value.toString()
    is Number -> value.toString()
    is String -> "\"${value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")}\""
    is List<*> -> "[${value.joinToString(", ") { toJson(it) }}]"
    is Map<*, *> -> "{${value.entries.joinToString(", ") { "\"${it.key}\": ${toJson(it.value)}" }}}"
    else -> "null"
}

fun main() {
    val input = generateSequence(::readLine).joinToString("\n")
    val vectors = parseJsonObject(input)
    
    println("{")
    println("""  "version": "1.0.0",""")
    println("""  "description": "Kotlin roundtrip results",""")
    
    val categories = listOf("primitives", "strings", "bytes", "options", "vectors", "structs", "complex")
    
    for ((ci, category) in categories.withIndex()) {
        println("""  "$category": [""")
        
        @Suppress("UNCHECKED_CAST")
        val tests = vectors[category] as? List<Map<String, Any?>> ?: emptyList()
        
        for ((ti, test) in tests.withIndex()) {
            val name = test["name"] as? String ?: ""
            val type = test["type"] as? String ?: ""
            val bcsHex = test["bcs_hex"] as? String ?: ""
            val value = test["value"]
            
            val result = processTestCase(name, type, bcsHex, value)
            val comma = if (ti < tests.size - 1) "," else ""
            println("    $result$comma")
        }
        
        val catComma = if (ci < categories.size - 1) "," else ""
        println("  ]$catComma")
    }
    
    println("}")
}
