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

data class BenchStats(val avg: Long, val min: Long, val max: Long, val p50: Long, val p95: Long)

fun computeStats(times: LongArray): BenchStats {
    times.sort()
    val avg = if (times.isNotEmpty()) times.sum() / times.size else 0L
    val min = times.minOrNull() ?: 0L
    val max = times.maxOrNull() ?: 0L
    val p50 = if (times.isNotEmpty()) times[times.size / 2] else 0L
    val p95 = if (times.isNotEmpty()) times[(times.size * 0.95).toInt().coerceIn(0, times.size - 1)] else 0L
    return BenchStats(avg, min, max, p50, p95)
}

fun generateBenchValue(bc: Map<String, Any?>): Any? {
    bc["value"]?.let { return it }
    val length = (bc["length"] as? Long)?.toInt() ?: 10
    return when (bc["value_generator"]) {
        "repeat_char" -> (bc["char"] as? String ?: "a").repeat(length)
        "sequential_bytes", "sequential_u8" -> (0 until length).map { it % 256 }
        "sequential_u64" -> (0 until length).map { it.toString() }
        "address_bytes" -> (0 until 31).map { 0 } + listOf(1)
        else -> bc["value"]
    }
}

fun serializeBenchValue(s: BcsSerializer, type: String, value: Any?) {
    when (type) {
        "bool" -> s.writeBool(value as? Boolean ?: false)
        "u8" -> s.writeU8(((value as? Long) ?: (value as? Int)?.toLong() ?: 0L).toInt())
        "u16" -> s.writeU16(((value as? Long) ?: 0L).toInt())
        "u32" -> s.writeU32((value as? Long) ?: 0L)
        "u64" -> s.writeU64((value as? String)?.toLongOrNull() ?: (value as? Long) ?: 0L)
        "u128", "i128" -> {
            val bytes = ByteArray(16) { 0 }
            s.writeFixedBytes(bytes, 16)
        }
        "i8" -> s.writeI8(((value as? Long) ?: 0L).toInt())
        "i16" -> s.writeI16(((value as? Long) ?: 0L).toInt())
        "i32" -> s.writeI32(((value as? Long) ?: 0L).toInt())
        "i64" -> s.writeI64((value as? String)?.toLongOrNull() ?: (value as? Long) ?: 0L)
        "string" -> s.writeString(value as? String ?: "")
        "bytes", "vector<u8>" -> {
            @Suppress("UNCHECKED_CAST")
            val arr = (value as? List<*>)?.mapNotNull { (it as? Long)?.toInt() ?: (it as? Int) } ?: emptyList()
            s.writeUleb128(arr.size)
            arr.forEach { s.writeU8(it) }
        }
        "fixed_bytes" -> {
            @Suppress("UNCHECKED_CAST")
            val arr = (value as? List<*>)?.mapNotNull { (it as? Long)?.toInt() ?: (it as? Int) } ?: emptyList()
            s.writeFixedBytes(ByteArray(arr.size) { arr[it].toByte() }, arr.size)
        }
        "vector<u64>" -> {
            @Suppress("UNCHECKED_CAST")
            val arr = (value as? List<*>)?.map { (it as? String)?.toLongOrNull() ?: (it as? Long) ?: 0L } ?: emptyList()
            s.writeUleb128(arr.size)
            arr.forEach { s.writeU64(it) }
        }
        "vector<string>" -> {
            @Suppress("UNCHECKED_CAST")
            val arr = (value as? List<*>)?.map { it as? String ?: "" } ?: emptyList()
            s.writeUleb128(arr.size)
            arr.forEach { s.writeString(it) }
        }
    }
}

fun deserializeBenchValue(d: BcsDeserializer, type: String) {
    when (type) {
        "bool" -> d.readBool()
        "u8" -> d.readU8()
        "u16" -> d.readU16()
        "u32" -> d.readU32()
        "u64" -> d.readU64()
        "u128", "i128" -> d.readFixedBytes(16)
        "i8" -> d.readI8()
        "i16" -> d.readI16()
        "i32" -> d.readI32()
        "i64" -> d.readI64()
        "string" -> d.readString()
        "bytes", "vector<u8>" -> {
            val len = d.readUleb128().toInt()
            repeat(len) { d.readU8() }
        }
        "fixed_bytes" -> d.readFixedBytes(32)
        "vector<u64>" -> {
            val len = d.readUleb128().toInt()
            repeat(len) { d.readU64() }
        }
        "vector<string>" -> {
            val len = d.readUleb128().toInt()
            repeat(len) { d.readString() }
        }
    }
}

fun runBenchmarks(input: String) {
    val spec = parseJsonObject(input)
    @Suppress("UNCHECKED_CAST")
    val config = spec["config"] as? Map<String, Any?> ?: emptyMap()
    val defaultIterations = ((config["iterations"] as? Long) ?: 1000L).toInt()
    val warmup = ((config["warmup"] as? Long) ?: 10L).toInt()
    
    println("{")
    println("""  "version": "1.0.0",""")
    println("""  "description": "Kotlin benchmark results",""")
    println("""  "benchmarks": [""")
    
    @Suppress("UNCHECKED_CAST")
    val scenarios = spec["scenarios"] as? Map<String, Any?> ?: emptyMap()
    var firstResult = true
    
    for ((_, catValue) in scenarios) {
        @Suppress("UNCHECKED_CAST")
        val category = catValue as? Map<String, Any?> ?: continue
        @Suppress("UNCHECKED_CAST")
        val benchmarks = category["benchmarks"] as? List<Map<String, Any?>> ?: continue
        
        for (bc in benchmarks) {
            val name = bc["name"] as? String ?: ""
            val type = bc["type"] as? String ?: ""
            val iterations = ((bc["iterations"] as? Long) ?: defaultIterations.toLong()).toInt()
            
            try {
                val value = generateBenchValue(bc)
                
                // Serialize to get bytes
                val ser = BcsSerializer()
                serializeBenchValue(ser, type, value)
                val bcsBytes = ser.toBytes()
                
                // Warmup serialize
                repeat(warmup) {
                    val ws = BcsSerializer()
                    serializeBenchValue(ws, type, value)
                    ws.toBytes()
                }
                
                // Benchmark serialize
                val serTimes = LongArray(iterations)
                repeat(iterations) { i ->
                    val start = System.nanoTime()
                    val bs = BcsSerializer()
                    serializeBenchValue(bs, type, value)
                    bs.toBytes()
                    serTimes[i] = System.nanoTime() - start
                }
                
                // Warmup deserialize
                repeat(warmup) {
                    val wd = BcsDeserializer(bcsBytes)
                    deserializeBenchValue(wd, type)
                }
                
                // Benchmark deserialize
                val deTimes = LongArray(iterations)
                repeat(iterations) { i ->
                    val start = System.nanoTime()
                    val bd = BcsDeserializer(bcsBytes)
                    deserializeBenchValue(bd, type)
                    deTimes[i] = System.nanoTime() - start
                }
                
                val serStats = computeStats(serTimes)
                val deStats = computeStats(deTimes)
                
                if (!firstResult) println(",")
                firstResult = false
                print("""    {"name": "$name", "type": "$type", "iterations": $iterations, """)
                print(""""serialize_avg_ns": ${serStats.avg}, "serialize_min_ns": ${serStats.min}, "serialize_max_ns": ${serStats.max}, "serialize_p50_ns": ${serStats.p50}, "serialize_p95_ns": ${serStats.p95}, """)
                print(""""deserialize_avg_ns": ${deStats.avg}, "deserialize_min_ns": ${deStats.min}, "deserialize_max_ns": ${deStats.max}, "deserialize_p50_ns": ${deStats.p50}, "deserialize_p95_ns": ${deStats.p95}}""")
            } catch (e: Exception) {
                if (!firstResult) println(",")
                firstResult = false
                print("""    {"name": "$name", "type": "$type", "error": "${e.message?.replace("\"", "\\\"")}"}""")
            }
        }
    }
    
    println()
    println("  ]")
    println("}")
}

fun main(args: Array<String>) {
    val input = generateSequence(::readLine).joinToString("\n")
    
    if (args.contains("--benchmark")) {
        runBenchmarks(input)
        return
    }
    
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
