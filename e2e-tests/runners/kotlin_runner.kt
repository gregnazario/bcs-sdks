#!/usr/bin/env kotlin
// Kotlin BCS E2E Test Runner
//
// Reads test vectors from stdin, performs roundtrip serialization,
// and outputs results to stdout.

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

// Simple BCS implementation for roundtrip testing
class BcsSerializer {
    private val buffer = ByteArrayOutputStream()

    fun writeBool(value: Boolean): BcsSerializer { buffer.write(if (value) 1 else 0); return this }
    fun writeU8(value: Int): BcsSerializer { buffer.write(value and 0xFF); return this }
    fun writeU16(value: Int): BcsSerializer {
        buffer.write(value and 0xFF)
        buffer.write((value shr 8) and 0xFF)
        return this
    }
    fun writeU32(value: Long): BcsSerializer {
        for (i in 0 until 4) buffer.write(((value shr (i * 8)) and 0xFF).toInt())
        return this
    }
    fun writeU64(value: Long): BcsSerializer {
        for (i in 0 until 8) buffer.write(((value shr (i * 8)) and 0xFF).toInt())
        return this
    }
    fun writeU128(bytes: ByteArray): BcsSerializer { buffer.write(bytes); return this }
    fun writeI8(value: Int): BcsSerializer { buffer.write(value and 0xFF); return this }
    fun writeI16(value: Int): BcsSerializer { writeU16(value and 0xFFFF); return this }
    fun writeI32(value: Int): BcsSerializer { writeU32(value.toLong() and 0xFFFFFFFFL); return this }
    fun writeI64(value: Long): BcsSerializer { writeU64(value); return this }
    fun writeI128(bytes: ByteArray): BcsSerializer { buffer.write(bytes); return this }
    
    fun writeUleb128(value: Int): BcsSerializer {
        var v = value
        do {
            var byte = v and 0x7F
            v = v ushr 7
            if (v != 0) byte = byte or 0x80
            buffer.write(byte)
        } while (v != 0)
        return this
    }
    
    fun writeString(s: String): BcsSerializer {
        val bytes = s.toByteArray(Charsets.UTF_8)
        writeUleb128(bytes.size)
        buffer.write(bytes)
        return this
    }
    
    fun writeBytes(bytes: ByteArray): BcsSerializer {
        writeUleb128(bytes.size)
        buffer.write(bytes)
        return this
    }
    
    fun writeFixedBytes(bytes: ByteArray): BcsSerializer { buffer.write(bytes); return this }
    fun toBytes(): ByteArray = buffer.toByteArray()
}

class BcsDeserializer(private val data: ByteArray) {
    private var offset = 0
    
    fun readBool(): Boolean {
        if (offset >= data.size) throw Exception("EOF")
        val b = data[offset++].toInt() and 0xFF
        if (b != 0 && b != 1) throw Exception("Invalid bool")
        return b == 1
    }
    
    fun readU8(): Int {
        if (offset >= data.size) throw Exception("EOF")
        return data[offset++].toInt() and 0xFF
    }
    
    fun readU16(): Int {
        if (offset + 2 > data.size) throw Exception("EOF")
        val v = (data[offset].toInt() and 0xFF) or ((data[offset + 1].toInt() and 0xFF) shl 8)
        offset += 2
        return v
    }
    
    fun readU32(): Long {
        if (offset + 4 > data.size) throw Exception("EOF")
        var v = 0L
        for (i in 0 until 4) v = v or ((data[offset + i].toLong() and 0xFF) shl (i * 8))
        offset += 4
        return v
    }
    
    fun readU64(): Long {
        if (offset + 8 > data.size) throw Exception("EOF")
        var v = 0L
        for (i in 0 until 8) v = v or ((data[offset + i].toLong() and 0xFF) shl (i * 8))
        offset += 8
        return v
    }
    
    fun readU128(): ByteArray {
        if (offset + 16 > data.size) throw Exception("EOF")
        val bytes = data.copyOfRange(offset, offset + 16)
        offset += 16
        return bytes
    }
    
    fun readI8(): Int {
        val u = readU8()
        return if (u < 128) u else u - 256
    }
    
    fun readI16(): Int {
        val u = readU16()
        return if (u < 32768) u else u - 65536
    }
    
    fun readI32(): Int {
        val u = readU32()
        return if (u < 2147483648L) u.toInt() else (u - 4294967296L).toInt()
    }
    
    fun readI64(): Long = readU64()
    fun readI128(): ByteArray = readU128()
    
    fun readUleb128(): Int {
        var value = 0
        var shift = 0
        while (true) {
            if (offset >= data.size) throw Exception("EOF")
            val byte = data[offset++].toInt() and 0xFF
            value = value or ((byte and 0x7F) shl shift)
            if ((byte and 0x80) == 0) break
            shift += 7
        }
        return value
    }
    
    fun readString(): String {
        val len = readUleb128()
        if (offset + len > data.size) throw Exception("EOF")
        val bytes = data.copyOfRange(offset, offset + len)
        offset += len
        return String(bytes, Charsets.UTF_8)
    }
    
    fun readBytes(): ByteArray {
        val len = readUleb128()
        if (offset + len > data.size) throw Exception("EOF")
        val bytes = data.copyOfRange(offset, offset + len)
        offset += len
        return bytes
    }
    
    fun readFixedBytes(len: Int): ByteArray {
        if (offset + len > data.size) throw Exception("EOF")
        val bytes = data.copyOfRange(offset, offset + len)
        offset += len
        return bytes
    }
    
    fun checkEnd() { if (offset != data.size) throw Exception("Remaining input") }
}

fun hexToBytes(hex: String): ByteArray {
    val bytes = ByteArray(hex.length / 2)
    for (i in bytes.indices) {
        bytes[i] = hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
    }
    return bytes
}

fun bytesToHex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }

fun processTestCase(tc: Map<String, Any?>): Map<String, Any?> {
    val name = tc["name"] as String
    val type = tc["type"] as String
    val bcsHex = tc["bcs_hex"] as String
    
    return try {
        val data = hexToBytes(bcsHex)
        val resultHex: String = when (type) {
            "bool" -> {
                val d = BcsDeserializer(data); val v = d.readBool(); d.checkEnd()
                bytesToHex(BcsSerializer().writeBool(v).toBytes())
            }
            "u8" -> {
                val d = BcsDeserializer(data); val v = d.readU8(); d.checkEnd()
                bytesToHex(BcsSerializer().writeU8(v).toBytes())
            }
            "u16" -> {
                val d = BcsDeserializer(data); val v = d.readU16(); d.checkEnd()
                bytesToHex(BcsSerializer().writeU16(v).toBytes())
            }
            "u32" -> {
                val d = BcsDeserializer(data); val v = d.readU32(); d.checkEnd()
                bytesToHex(BcsSerializer().writeU32(v).toBytes())
            }
            "u64" -> {
                val d = BcsDeserializer(data); val v = d.readU64(); d.checkEnd()
                bytesToHex(BcsSerializer().writeU64(v).toBytes())
            }
            "u128" -> {
                val d = BcsDeserializer(data); val v = d.readU128(); d.checkEnd()
                bytesToHex(BcsSerializer().writeU128(v).toBytes())
            }
            "i8" -> {
                val d = BcsDeserializer(data); val v = d.readI8(); d.checkEnd()
                bytesToHex(BcsSerializer().writeI8(v).toBytes())
            }
            "i16" -> {
                val d = BcsDeserializer(data); val v = d.readI16(); d.checkEnd()
                bytesToHex(BcsSerializer().writeI16(v).toBytes())
            }
            "i32" -> {
                val d = BcsDeserializer(data); val v = d.readI32(); d.checkEnd()
                bytesToHex(BcsSerializer().writeI32(v).toBytes())
            }
            "i64" -> {
                val d = BcsDeserializer(data); val v = d.readI64(); d.checkEnd()
                bytesToHex(BcsSerializer().writeI64(v).toBytes())
            }
            "i128" -> {
                val d = BcsDeserializer(data); val v = d.readI128(); d.checkEnd()
                bytesToHex(BcsSerializer().writeI128(v).toBytes())
            }
            "string" -> {
                val d = BcsDeserializer(data); val v = d.readString(); d.checkEnd()
                bytesToHex(BcsSerializer().writeString(v).toBytes())
            }
            "bytes" -> {
                val d = BcsDeserializer(data); val v = d.readBytes(); d.checkEnd()
                bytesToHex(BcsSerializer().writeBytes(v).toBytes())
            }
            "fixed_bytes_32" -> {
                val d = BcsDeserializer(data); val v = d.readFixedBytes(32); d.checkEnd()
                bytesToHex(BcsSerializer().writeFixedBytes(v).toBytes())
            }
            "option<u8>" -> {
                val d = BcsDeserializer(data); val hasVal = d.readBool()
                val s = BcsSerializer().writeBool(hasVal)
                if (hasVal) s.writeU8(d.readU8())
                d.checkEnd(); bytesToHex(s.toBytes())
            }
            "option<u64>" -> {
                val d = BcsDeserializer(data); val hasVal = d.readBool()
                val s = BcsSerializer().writeBool(hasVal)
                if (hasVal) s.writeU64(d.readU64())
                d.checkEnd(); bytesToHex(s.toBytes())
            }
            "option<bool>" -> {
                val d = BcsDeserializer(data); val hasVal = d.readBool()
                val s = BcsSerializer().writeBool(hasVal)
                if (hasVal) s.writeBool(d.readBool())
                d.checkEnd(); bytesToHex(s.toBytes())
            }
            "option<string>" -> {
                val d = BcsDeserializer(data); val hasVal = d.readBool()
                val s = BcsSerializer().writeBool(hasVal)
                if (hasVal) s.writeString(d.readString())
                d.checkEnd(); bytesToHex(s.toBytes())
            }
            "vector<u8>" -> {
                val d = BcsDeserializer(data); val len = d.readUleb128()
                val vals = (0 until len).map { d.readU8() }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(vals.size)
                vals.forEach { s.writeU8(it) }
                bytesToHex(s.toBytes())
            }
            "vector<u64>" -> {
                val d = BcsDeserializer(data); val len = d.readUleb128()
                val vals = (0 until len).map { d.readU64() }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(vals.size)
                vals.forEach { s.writeU64(it) }
                bytesToHex(s.toBytes())
            }
            "vector<bool>" -> {
                val d = BcsDeserializer(data); val len = d.readUleb128()
                val vals = (0 until len).map { d.readBool() }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(vals.size)
                vals.forEach { s.writeBool(it) }
                bytesToHex(s.toBytes())
            }
            "vector<vector<u8>>" -> {
                val d = BcsDeserializer(data); val outerLen = d.readUleb128()
                val outer = (0 until outerLen).map {
                    val innerLen = d.readUleb128()
                    (0 until innerLen).map { d.readU8() }
                }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(outer.size)
                outer.forEach { inner ->
                    s.writeUleb128(inner.size)
                    inner.forEach { s.writeU8(it) }
                }
                bytesToHex(s.toBytes())
            }
            "vector<string>" -> {
                val d = BcsDeserializer(data); val len = d.readUleb128()
                val vals = (0 until len).map { d.readString() }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(vals.size)
                vals.forEach { s.writeString(it) }
                bytesToHex(s.toBytes())
            }
            "struct" -> {
                @Suppress("UNCHECKED_CAST")
                val fields = (tc["value"] as Map<String, Any?>)["fields"] as List<Map<String, Any?>>
                val d = BcsDeserializer(data)
                val s = BcsSerializer()
                fields.forEach { field ->
                    when (field["type"] as String) {
                        "u8" -> s.writeU8(d.readU8())
                        "u64" -> s.writeU64(d.readU64())
                        "string" -> s.writeString(d.readString())
                        "fixed_bytes_32" -> s.writeFixedBytes(d.readFixedBytes(32))
                    }
                }
                d.checkEnd(); bytesToHex(s.toBytes())
            }
            "map<u8,u8>" -> {
                val d = BcsDeserializer(data); val len = d.readUleb128()
                val pairs = (0 until len).map { Pair(d.readU8(), d.readU8()) }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(pairs.size)
                pairs.forEach { s.writeU8(it.first); s.writeU8(it.second) }
                bytesToHex(s.toBytes())
            }
            "map<string,u64>" -> {
                val d = BcsDeserializer(data); val len = d.readUleb128()
                val pairs = (0 until len).map { Pair(d.readString(), d.readU64()) }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(pairs.size)
                pairs.forEach { s.writeString(it.first); s.writeU64(it.second) }
                bytesToHex(s.toBytes())
            }
            "tuple<u8,u64>" -> {
                val d = BcsDeserializer(data); val a = d.readU8(); val b = d.readU64()
                d.checkEnd()
                bytesToHex(BcsSerializer().writeU8(a).writeU64(b).toBytes())
            }
            "vector<option<u8>>" -> {
                val d = BcsDeserializer(data); val len = d.readUleb128()
                val vals = (0 until len).map {
                    val hasVal = d.readBool()
                    if (hasVal) d.readU8() else null
                }
                d.checkEnd()
                val s = BcsSerializer().writeUleb128(vals.size)
                vals.forEach { v ->
                    s.writeBool(v != null)
                    if (v != null) s.writeU8(v)
                }
                bytesToHex(s.toBytes())
            }
            else -> return mapOf("name" to name, "type" to type, "bcs_hex" to "", "value" to tc["value"], "error" to "Unknown type: $type")
        }
        mapOf("name" to name, "type" to type, "bcs_hex" to resultHex, "value" to tc["value"])
    } catch (e: Exception) {
        mapOf("name" to name, "type" to type, "bcs_hex" to "", "value" to tc["value"], "error" to e.message)
    }
}

// Simple JSON parser/serializer (since we can't easily use external deps in kotlin script)
fun parseJson(json: String): Any? {
    var idx = 0
    fun skipWhitespace() { while (idx < json.length && json[idx].isWhitespace()) idx++ }
    fun parseValue(): Any? {
        skipWhitespace()
        return when {
            json[idx] == '"' -> parseString()
            json[idx] == '{' -> parseObject()
            json[idx] == '[' -> parseArray()
            json[idx] == 't' -> { idx += 4; true }
            json[idx] == 'f' -> { idx += 5; false }
            json[idx] == 'n' -> { idx += 4; null }
            else -> parseNumber()
        }
    }
    fun parseString(): String {
        idx++ // skip opening "
        val sb = StringBuilder()
        while (json[idx] != '"') {
            if (json[idx] == '\\') {
                idx++
                when (json[idx]) {
                    '"', '\\', '/' -> sb.append(json[idx])
                    'n' -> sb.append('\n')
                    'r' -> sb.append('\r')
                    't' -> sb.append('\t')
                    'u' -> { sb.append(json.substring(idx + 1, idx + 5).toInt(16).toChar()); idx += 4 }
                }
            } else sb.append(json[idx])
            idx++
        }
        idx++ // skip closing "
        return sb.toString()
    }
    fun parseObject(): Map<String, Any?> {
        idx++ // skip {
        val map = mutableMapOf<String, Any?>()
        skipWhitespace()
        if (json[idx] != '}') {
            while (true) {
                skipWhitespace()
                val key = parseString()
                skipWhitespace()
                idx++ // skip :
                map[key] = parseValue()
                skipWhitespace()
                if (json[idx] == '}') break
                idx++ // skip ,
            }
        }
        idx++ // skip }
        return map
    }
    fun parseArray(): List<Any?> {
        idx++ // skip [
        val list = mutableListOf<Any?>()
        skipWhitespace()
        if (json[idx] != ']') {
            while (true) {
                list.add(parseValue())
                skipWhitespace()
                if (json[idx] == ']') break
                idx++ // skip ,
            }
        }
        idx++ // skip ]
        return list
    }
    fun parseNumber(): Any {
        val start = idx
        if (json[idx] == '-') idx++
        while (idx < json.length && (json[idx].isDigit() || json[idx] == '.' || json[idx] == 'e' || json[idx] == 'E' || json[idx] == '+' || json[idx] == '-')) idx++
        val num = json.substring(start, idx)
        return if (num.contains('.') || num.contains('e') || num.contains('E')) num.toDouble() else num.toLong()
    }
    return parseValue()
}

fun toJson(obj: Any?, indent: Int = 0): String {
    val spaces = "  ".repeat(indent)
    val nextSpaces = "  ".repeat(indent + 1)
    return when (obj) {
        null -> "null"
        is Boolean -> obj.toString()
        is Number -> obj.toString()
        is String -> "\"${obj.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")}\""
        is List<*> -> if (obj.isEmpty()) "[]" else "[\n${obj.joinToString(",\n") { "$nextSpaces${toJson(it, indent + 1)}" }}\n$spaces]"
        is Map<*, *> -> if (obj.isEmpty()) "{}" else "{\n${obj.entries.joinToString(",\n") { (k, v) -> "$nextSpaces\"$k\": ${toJson(v, indent + 1)}" }}\n$spaces}"
        else -> "null"
    }
}

fun main() {
    val input = generateSequence(::readLine).joinToString("\n")
    @Suppress("UNCHECKED_CAST")
    val vectors = parseJson(input) as Map<String, Any?>
    
    @Suppress("UNCHECKED_CAST")
    fun processList(key: String) = (vectors[key] as? List<Map<String, Any?>>)?.map { processTestCase(it) } ?: emptyList()
    
    val output = mapOf(
        "version" to (vectors["version"] ?: "1.0.0"),
        "description" to "Kotlin roundtrip results",
        "primitives" to processList("primitives"),
        "strings" to processList("strings"),
        "bytes" to processList("bytes"),
        "options" to processList("options"),
        "vectors" to processList("vectors"),
        "structs" to processList("structs"),
        "complex" to processList("complex")
    )
    
    println(toJson(output))
}

main()
