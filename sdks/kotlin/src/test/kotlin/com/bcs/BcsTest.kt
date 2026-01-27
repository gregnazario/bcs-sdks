package com.bcs

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.assertThrows
import java.math.BigInteger
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class BcsTest {

    // =========================================================================
    // Boolean Tests
    // =========================================================================

    @Nested
    inner class BooleanTests {
        @Test
        fun `serialize true`() {
            val bytes = bcsSerialize { writeBool(true) }
            assertEquals(listOf(0x01.toByte()), bytes.toList())
        }

        @Test
        fun `serialize false`() {
            val bytes = bcsSerialize { writeBool(false) }
            assertEquals(listOf(0x00.toByte()), bytes.toList())
        }

        @Test
        fun `deserialize boolean`() {
            val result = bcsDeserialize(byteArrayOf(0x01, 0x00)) {
                Pair(readBool(), readBool())
            }
            assertEquals(Pair(true, false), result)
        }

        @Test
        fun `invalid boolean`() {
            assertThrows<BcsError> {
                bcsDeserialize(byteArrayOf(0x02)) { readBool() }
            }
        }
    }

    // =========================================================================
    // Integer Tests
    // =========================================================================

    @Nested
    inner class IntegerTests {
        @Test
        fun `serialize u8`() {
            val bytes = bcsSerialize { writeU8(42) }
            assertEquals(listOf(0x2a.toByte()), bytes.toList())
        }

        @Test
        fun `serialize u16`() {
            val bytes = bcsSerialize { writeU16(0x1234) }
            assertEquals(listOf(0x34, 0x12).map { it.toByte() }, bytes.toList())
        }

        @Test
        fun `serialize u32`() {
            val bytes = bcsSerialize { writeU32(0x12345678) }
            assertEquals(listOf(0x78, 0x56, 0x34, 0x12).map { it.toByte() }, bytes.toList())
        }

        @Test
        fun `serialize u64`() {
            val bytes = bcsSerialize { writeU64(0x123456789ABCDEF0) }
            val expected = listOf(0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12)
                .map { it.toByte() }
            assertEquals(expected, bytes.toList())
        }

        @Test
        fun `serialize i8`() {
            val bytes = bcsSerialize { writeI8(-1) }
            assertEquals(listOf(0xFF.toByte()), bytes.toList())
        }

        @Test
        fun `serialize i16`() {
            val bytes = bcsSerialize { writeI16(-32768) }
            assertEquals(listOf(0x00, 0x80).map { it.toByte() }, bytes.toList())
        }

        @Test
        fun `deserialize integers`() {
            val result = bcsDeserialize(byteArrayOf(0x2a, 0x34, 0x12)) {
                Pair(readU8(), readU16())
            }
            assertEquals(Pair(42, 0x1234), result)
        }
    }

    // =========================================================================
    // String Tests
    // =========================================================================

    @Nested
    inner class StringTests {
        @Test
        fun `serialize empty string`() {
            val bytes = bcsSerialize { writeString("") }
            assertEquals(listOf(0x00.toByte()), bytes.toList())
        }

        @Test
        fun `serialize hello`() {
            val bytes = bcsSerialize { writeString("hello") }
            assertEquals(
                listOf(0x05, 'h'.code, 'e'.code, 'l'.code, 'l'.code, 'o'.code).map { it.toByte() },
                bytes.toList()
            )
        }

        @Test
        fun `deserialize string`() {
            val data = byteArrayOf(0x05, 'h'.code.toByte(), 'e'.code.toByte(),
                'l'.code.toByte(), 'l'.code.toByte(), 'o'.code.toByte())
            val result = bcsDeserialize(data) { readString() }
            assertEquals("hello", result)
        }

        @Test
        fun `round trip unicode`() {
            val original = "Hello, 世界! 🌍"
            val bytes = bcsSerialize { writeString(original) }
            val result = bcsDeserialize(bytes) { readString() }
            assertEquals(original, result)
        }
    }

    // =========================================================================
    // Option Tests
    // =========================================================================

    @Nested
    inner class OptionTests {
        @Test
        fun `serialize some`() {
            val bytes = bcsSerialize { writeOption(42) { writeU8(it) } }
            assertEquals(listOf(0x01, 0x2a).map { it.toByte() }, bytes.toList())
        }

        @Test
        fun `serialize none`() {
            val bytes = bcsSerialize { writeOption<Int>(null) { writeU8(it) } }
            assertEquals(listOf(0x00.toByte()), bytes.toList())
        }

        @Test
        fun `deserialize some`() {
            val result = bcsDeserialize(byteArrayOf(0x01, 0x2a)) {
                readOption { readU8() }
            }
            assertEquals(42, result)
        }

        @Test
        fun `deserialize none`() {
            val result = bcsDeserialize(byteArrayOf(0x00)) {
                readOption { readU8() }
            }
            assertNull(result)
        }
    }

    // =========================================================================
    // List Tests
    // =========================================================================

    @Nested
    inner class ListTests {
        @Test
        fun `serialize empty list`() {
            val bytes = bcsSerialize { writeList(emptyList<Int>()) { writeU8(it) } }
            assertEquals(listOf(0x00.toByte()), bytes.toList())
        }

        @Test
        fun `serialize u8 list`() {
            val bytes = bcsSerialize { writeList(listOf(1, 2, 3)) { writeU8(it) } }
            assertEquals(listOf(0x03, 0x01, 0x02, 0x03).map { it.toByte() }, bytes.toList())
        }

        @Test
        fun `deserialize list`() {
            val data = byteArrayOf(0x03, 0x01, 0x02, 0x03)
            val result = bcsDeserialize(data) { readList { readU8() } }
            assertEquals(listOf(1, 2, 3), result)
        }

        @Test
        fun `round trip string list`() {
            val original = listOf("foo", "bar", "baz")
            val bytes = bcsSerialize { writeStringList(original) }
            val result = bcsDeserialize(bytes) { readStringList() }
            assertEquals(original, result)
        }
    }

    // =========================================================================
    // Map Tests
    // =========================================================================

    @Nested
    inner class MapTests {
        @Test
        fun `deserialize u8 map`() {
            // 3 entries: (1, 10), (2, 20), (3, 30)
            val data = byteArrayOf(0x03, 0x01, 0x0a, 0x02, 0x14, 0x03, 0x1e)
            val result = bcsDeserialize(data) {
                readMap({ readU8() }, { readU8() })
            }
            assertEquals(mapOf(1 to 10, 2 to 20, 3 to 30), result)
        }
    }

    // =========================================================================
    // Struct Tests
    // =========================================================================

    @Nested
    inner class StructTests {
        @Test
        fun `serialize struct`() {
            val bytes = bcsSerialize {
                writeStruct {
                    writeString("Alice")
                    writeU32(30)
                }
            }

            val result = bcsDeserialize(bytes) {
                readStruct {
                    Pair(readString(), readU32())
                }
            }

            assertEquals(Pair("Alice", 30L), result)
        }
    }

    // =========================================================================
    // Enum Tests
    // =========================================================================

    @Nested
    inner class EnumTests {
        @Test
        fun `serialize enum variant`() {
            val bytes = bcsSerialize {
                writeEnum(1) {
                    writeU64(42)
                }
            }

            val result = bcsDeserialize(bytes) {
                readEnum { variant ->
                    when (variant) {
                        0 -> "zero"
                        1 -> "one:${readU64()}"
                        else -> "unknown"
                    }
                }
            }

            assertEquals("one:42", result)
        }
    }

    // =========================================================================
    // BigInteger Tests
    // =========================================================================

    @Nested
    inner class BigIntegerTests {
        @Test
        fun `serialize u128`() {
            val value = BigInteger.ONE.shiftLeft(100).add(BigInteger.valueOf(255))
            val bytes = bcsSerialize { writeU128(value) }
            assertEquals(16, bytes.size)

            val result = bcsDeserialize(bytes) { readU128AsBigInteger() }
            assertEquals(value, result)
        }

        @Test
        fun `serialize u256`() {
            val value = BigInteger.ONE.shiftLeft(200).add(BigInteger.valueOf(1000))
            val bytes = bcsSerialize { writeU256(value) }
            assertEquals(32, bytes.size)

            val result = bcsDeserialize(bytes) { readU256AsBigInteger() }
            assertEquals(value, result)
        }
    }

    // =========================================================================
    // DSL Tests
    // =========================================================================

    @Nested
    inner class DslTests {
        @Test
        fun `infix write syntax`() {
            val bytes = BcsSerializer().apply {
                this write true
                this write "hello"
            }.toBytes()

            bcsDeserialize(bytes) {
                assertTrue(readBool())
                assertEquals("hello", readString())
            }
        }
    }

    // =========================================================================
    // Error Handling Tests
    // =========================================================================

    @Nested
    inner class ErrorTests {
        @Test
        fun `unexpected EOF`() {
            assertThrows<BcsError> {
                bcsDeserialize(byteArrayOf(0x01)) { readU16() }
            }
        }

        @Test
        fun `remaining input`() {
            assertThrows<BcsError> {
                bcsDeserialize(byteArrayOf(0x01, 0x02)) { readU8() }
                // checkEnd is called automatically
            }
        }
    }

    // =========================================================================
    // Round-trip Tests
    // =========================================================================

    @Nested
    inner class RoundTripTests {
        @Test
        fun `round trip complex`() {
            val bytes = bcsSerialize {
                writeU8(42)
                writeString("test")
                writeList(listOf(100, 200, 300)) { writeU16(it) }
                writeOption("optional") { writeString(it) }
            }

            bcsDeserialize(bytes) {
                assertEquals(42, readU8())
                assertEquals("test", readString())
                assertEquals(listOf(100, 200, 300), readList { readU16() })
                assertEquals("optional", readOption { readString() })
            }
        }
    }

    // =========================================================================
    // Hex Utilities Tests
    // =========================================================================

    @Nested
    inner class HexTests {
        @Test
        fun `bytes to hex`() {
            val bytes = byteArrayOf(0x01, 0x02, 0xab.toByte(), 0xcd.toByte())
            assertEquals("0102abcd", bytes.toHex())
        }

        @Test
        fun `hex to bytes`() {
            val bytes = "0102abcd".hexToBytes()
            assertEquals(listOf(0x01, 0x02, 0xab, 0xcd).map { it.toByte() }, bytes.toList())
        }
    }

    // =========================================================================
    // BcsSerializable Interface Tests
    // =========================================================================

    data class Person(val name: String, val age: Int) : BcsSerializable {
        override fun serialize(): ByteArray = bcsSerialize {
            writeString(name)
            writeU32(age.toLong())
        }

        override fun serialize(serializer: BcsSerializer) {
            serializer.writeString(name)
            serializer.writeU32(age.toLong())
        }

        companion object : BcsDeserializable<Person> {
            override fun deserialize(data: ByteArray): Person = bcsDeserialize(data) {
                Person(readString(), readU32().toInt())
            }

            override fun deserialize(deserializer: BcsDeserializer): Person {
                return Person(
                    deserializer.readString(),
                    deserializer.readU32().toInt()
                )
            }
        }
    }

    @Nested
    inner class SerializableTests {
        @Test
        fun `serialize data class`() {
            val person = Person("Alice", 30)
            val bytes = person.serialize()

            val result = Person.deserialize(bytes)
            assertEquals(person, result)
        }

        @Test
        fun `serialize with serializer`() {
            val person = Person("Bob", 25)
            val bytes = bcsSerialize {
                write(person)
            }

            val result = bcsDeserialize(bytes) {
                read(Person)
            }
            assertEquals(person, result)
        }
    }
}
