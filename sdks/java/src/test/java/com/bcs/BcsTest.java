package com.bcs;

import static org.junit.jupiter.api.Assertions.*;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.File;
import java.math.BigInteger;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

class BcsTest {

    private static JsonNode testVectors;
    private static final ObjectMapper mapper = new ObjectMapper();

    @BeforeAll
    static void loadTestVectors() {
        String vectorsPath = System.getProperty("TEST_VECTORS", "../../test-vectors");
        File file = new File(vectorsPath, "bcs-comprehensive.json");
        if (file.exists()) {
            try {
                testVectors = mapper.readTree(file);
            } catch (Exception e) {
                testVectors = null;
            }
        }
    }

    private static byte[] hexToBytes(String hex) {
        int len = hex.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(hex.charAt(i), 16) << 4)
                    + Character.digit(hex.charAt(i + 1), 16));
        }
        return data;
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    private JsonNode getTestVectors(String... path) {
        if (testVectors == null) {
            return null;
        }
        JsonNode node = testVectors;
        for (String key : path) {
            node = node.get(key);
            if (node == null) {
                return null;
            }
        }
        return node;
    }

    // ==========================================================================
    // BOOLEAN TESTS
    // ==========================================================================

    @Nested
    @DisplayName("Boolean serialization")
    class BooleanTests {

        @Test
        void serializeTrue() {
            BcsSerializer ser = new BcsSerializer();
            ser.writeBool(true);
            assertEquals("01", bytesToHex(ser.toBytes()));
        }

        @Test
        void serializeFalse() {
            BcsSerializer ser = new BcsSerializer();
            ser.writeBool(false);
            assertEquals("00", bytesToHex(ser.toBytes()));
        }

        @Test
        void deserializeTrue() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("01"));
            assertTrue(des.readBool());
        }

        @Test
        void deserializeFalse() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("00"));
            assertFalse(des.readBool());
        }

        @Test
        void rejectInvalidBoolean() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("02"));
            BcsError error = assertThrows(BcsError.class, des::readBool);
            assertEquals(BcsError.Type.INVALID_BOOLEAN, error.getType());
        }
    }

    // ==========================================================================
    // UNSIGNED INTEGER TESTS
    // ==========================================================================

    @Nested
    @DisplayName("U8 serialization")
    class U8Tests {

        @Test
        void serializeU8Zero() {
            BcsSerializer ser = new BcsSerializer();
            ser.writeU8((short) 0);
            assertEquals("00", bytesToHex(ser.toBytes()));
        }

        @Test
        void serializeU8Max() {
            BcsSerializer ser = new BcsSerializer();
            ser.writeU8((short) 255);
            assertEquals("ff", bytesToHex(ser.toBytes()));
        }

        @Test
        void deserializeU8() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("2a"));
            assertEquals(42, des.readU8());
        }

        @Test
        void testVectorsU8() {
            JsonNode vectors = getTestVectors("primitives", "u8", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                int value = tc.get("value").asInt();
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeU8((short) value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readU8(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    @Nested
    @DisplayName("U16 serialization")
    class U16Tests {

        @Test
        void testVectorsU16() {
            JsonNode vectors = getTestVectors("primitives", "u16", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                int value = tc.get("value").asInt();
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeU16(value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readU16(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    @Nested
    @DisplayName("U32 serialization")
    class U32Tests {

        @Test
        void testVectorsU32() {
            JsonNode vectors = getTestVectors("primitives", "u32", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                long value = tc.get("value").asLong();
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeU32(value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readU32(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    @Nested
    @DisplayName("U64 serialization")
    class U64Tests {

        @Test
        void testVectorsU64() {
            JsonNode vectors = getTestVectors("primitives", "u64", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                String valueStr = tc.get("value").asText();
                // Handle large values that might exceed long
                BigInteger bigValue = new BigInteger(valueStr);
                long value = bigValue.longValue();
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeU64(value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readU64(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    @Nested
    @DisplayName("U128 serialization")
    class U128Tests {

        @Test
        void testVectorsU128() {
            JsonNode vectors = getTestVectors("primitives", "u128", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                BigInteger value = new BigInteger(tc.get("value").asText());
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeU128(value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readU128(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    @Nested
    @DisplayName("U256 serialization")
    class U256Tests {

        @Test
        void testVectorsU256() {
            JsonNode vectors = getTestVectors("primitives", "u256", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                BigInteger value = new BigInteger(tc.get("value").asText());
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeU256(value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readU256(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    // ==========================================================================
    // SIGNED INTEGER TESTS
    // ==========================================================================

    @Nested
    @DisplayName("I8 serialization")
    class I8Tests {

        @Test
        void testVectorsI8() {
            JsonNode vectors = getTestVectors("primitives", "i8", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                int value = tc.get("value").asInt();
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeI8((byte) value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readI8(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    @Nested
    @DisplayName("I32 serialization")
    class I32Tests {

        @Test
        void testVectorsI32() {
            JsonNode vectors = getTestVectors("primitives", "i32", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                int value = tc.get("value").asInt();
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeI32(value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readI32(), "deserialize " + tc.get("name").asText());
            }
        }
    }

    // ==========================================================================
    // ULEB128 TESTS
    // ==========================================================================

    @Nested
    @DisplayName("ULEB128 encoding")
    class Uleb128Tests {

        @Test
        void testVectorsUleb128() {
            JsonNode vectors = getTestVectors("uleb128", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                long value = tc.get("value").asLong();
                String bcsHex = tc.get("bcs_hex").asText();

                byte[] encoded = Uleb128.encode(value);
                assertEquals(bcsHex, bytesToHex(encoded), "encode " + tc.get("name").asText());

                Uleb128.DecodeResult result = Uleb128.decode(hexToBytes(bcsHex), 0);
                assertEquals(value, result.getValue(), "decode " + tc.get("name").asText());
            }
        }

        @Test
        void rejectNonCanonicalEncoding() {
            // 0x80 0x00 is non-canonical for 0
            BcsError error = assertThrows(BcsError.class, () -> Uleb128.decode(new byte[] {(byte) 0x80, 0x00}, 0));
            assertEquals(BcsError.Type.NON_CANONICAL_ULEB128, error.getType());
        }

        @Test
        void rejectOverflow() {
            // 6 bytes with continuation bits
            BcsError error = assertThrows(
                    BcsError.class,
                    () -> Uleb128.decode(new byte[] {(byte) 0x80, (byte) 0x80, (byte) 0x80, (byte) 0x80, (byte) 0x80, 0x01}, 0));
            assertEquals(BcsError.Type.ULEB128_OVERFLOW, error.getType());
        }
    }

    // ==========================================================================
    // STRING TESTS
    // ==========================================================================

    @Nested
    @DisplayName("String serialization")
    class StringTests {

        @Test
        void testVectorsString() {
            JsonNode vectors = getTestVectors("strings", "valid");
            if (vectors == null) {
                return;
            }
            for (JsonNode tc : vectors) {
                String value = tc.get("value").asText();
                String bcsHex = tc.get("bcs_hex").asText();

                BcsSerializer ser = new BcsSerializer();
                ser.writeString(value);
                assertEquals(bcsHex, bytesToHex(ser.toBytes()), "serialize " + tc.get("name").asText());

                BcsDeserializer des = new BcsDeserializer(hexToBytes(bcsHex));
                assertEquals(value, des.readString(), "deserialize " + tc.get("name").asText());
            }
        }

        @Test
        void rejectInvalidUtf8() {
            // Length 1, byte 0xFF (invalid UTF-8)
            BcsDeserializer des = new BcsDeserializer(hexToBytes("01ff"));
            BcsError error = assertThrows(BcsError.class, des::readString);
            assertEquals(BcsError.Type.INVALID_UTF8, error.getType());
        }
    }

    // ==========================================================================
    // OPTION TESTS
    // ==========================================================================

    @Nested
    @DisplayName("Option serialization")
    class OptionTests {

        @Test
        void serializeNone() {
            BcsSerializer ser = new BcsSerializer();
            ser.writeOption(null, (s, v) -> s.writeU8((Short) v));
            assertEquals("00", bytesToHex(ser.toBytes()));
        }

        @Test
        void serializeSome() {
            BcsSerializer ser = new BcsSerializer();
            ser.writeOption((short) 42, (s, v) -> s.writeU8(v));
            assertEquals("012a", bytesToHex(ser.toBytes()));
        }

        @Test
        void deserializeNone() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("00"));
            assertNull(des.readOption(BcsDeserializer::readU8));
        }

        @Test
        void deserializeSome() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("012a"));
            assertEquals((short) 42, des.readOption(BcsDeserializer::readU8));
        }

        @Test
        void rejectInvalidOptionTag() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("02"));
            BcsError error = assertThrows(BcsError.class, () -> des.readOption(BcsDeserializer::readU8));
            assertEquals(BcsError.Type.INVALID_OPTION, error.getType());
        }
    }

    // ==========================================================================
    // VECTOR TESTS
    // ==========================================================================

    @Nested
    @DisplayName("Vector serialization")
    class VectorTests {

        @Test
        void serializeEmptyVector() {
            BcsSerializer ser = new BcsSerializer();
            ser.writeVector(List.of(), (s, v) -> s.writeU8((Short) v));
            assertEquals("00", bytesToHex(ser.toBytes()));
        }

        @Test
        void serializeVector123() {
            BcsSerializer ser = new BcsSerializer();
            List<Short> values = List.of((short) 1, (short) 2, (short) 3);
            ser.writeVector(values, (s, v) -> s.writeU8(v));
            assertEquals("03010203", bytesToHex(ser.toBytes()));
        }

        @Test
        void deserializeEmptyVector() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("00"));
            List<Short> result = des.readVector(BcsDeserializer::readU8);
            assertTrue(result.isEmpty());
        }

        @Test
        void deserializeVector123() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("03010203"));
            List<Short> result = des.readVector(BcsDeserializer::readU8);
            assertEquals(List.of((short) 1, (short) 2, (short) 3), result);
        }
    }

    // ==========================================================================
    // ERROR CASE TESTS
    // ==========================================================================

    @Nested
    @DisplayName("Error cases")
    class ErrorTests {

        @Test
        void remainingInput() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("0001"));
            des.readBool();
            BcsError error = assertThrows(BcsError.class, des::checkEnd);
            assertEquals(BcsError.Type.REMAINING_INPUT, error.getType());
        }

        @Test
        void unexpectedEofOnU64() {
            BcsDeserializer des = new BcsDeserializer(hexToBytes("010203"));
            BcsError error = assertThrows(BcsError.class, des::readU64);
            assertEquals(BcsError.Type.UNEXPECTED_EOF, error.getType());
        }

        @Test
        void unexpectedEofOnEmptyInput() {
            BcsDeserializer des = new BcsDeserializer(new byte[0]);
            BcsError error = assertThrows(BcsError.class, des::readU8);
            assertEquals(BcsError.Type.UNEXPECTED_EOF, error.getType());
        }
    }

    // ==========================================================================
    // MAP TESTS
    // ==========================================================================

    @Nested
    @DisplayName("Map serialization")
    class MapTests {

        @Test
        void serializeSortedMap() {
            BcsSerializer ser = new BcsSerializer();
            java.util.Map<Short, Short> map = new java.util.LinkedHashMap<>();
            map.put((short) 1, (short) 10);
            map.put((short) 2, (short) 20);
            map.put((short) 3, (short) 30);
            ser.writeMap(map, (s, k) -> s.writeU8(k), (s, v) -> s.writeU8(v));
            // Length 3, then (1, 0x0a), (2, 0x14), (3, 0x1e) - values are 10, 20, 30 in hex
            assertEquals("03010a0214031e", bytesToHex(ser.toBytes()));
        }

        @Test
        void deserializeValidMap() {
            // Length 3, keys in sorted order: (1, 10), (2, 20), (3, 30) - 30 decimal = 0x1e
            BcsDeserializer des = new BcsDeserializer(hexToBytes("03010a0214031e"));
            java.util.Map<Short, Short> result = des.readMap(BcsDeserializer::readU8, BcsDeserializer::readU8);
            assertEquals(3, result.size());
            assertEquals((short) 10, result.get((short) 1));
            assertEquals((short) 20, result.get((short) 2));
            assertEquals((short) 30, result.get((short) 3));
        }

        @Test
        void rejectUnsortedKeys() {
            // Length 3, keys NOT sorted: (2, 20), (1, 10) - 2 > 1 is wrong order
            BcsDeserializer des = new BcsDeserializer(hexToBytes("0302140110"));
            BcsError error = assertThrows(BcsError.class, () ->
                    des.readMap(BcsDeserializer::readU8, BcsDeserializer::readU8));
            assertEquals(BcsError.Type.NON_CANONICAL_MAP, error.getType());
        }

        @Test
        void rejectDuplicateKeys() {
            // Length 2, duplicate key 1: (1, 10), (1, 10)
            BcsDeserializer des = new BcsDeserializer(hexToBytes("0201100110"));
            BcsError error = assertThrows(BcsError.class, () ->
                    des.readMap(BcsDeserializer::readU8, BcsDeserializer::readU8));
            assertEquals(BcsError.Type.NON_CANONICAL_MAP, error.getType());
        }
    }

    // ==========================================================================
    // CONTAINER DEPTH TESTS
    // ==========================================================================

    @Nested
    @DisplayName("Container depth")
    class ContainerDepthTests {

        @Test
        void allowsUpTo500NestedStructsSerializer() {
            BcsSerializer ser = new BcsSerializer();
            // Enter 500 nested structs (at max depth)
            for (int i = 0; i < 500; i++) {
                ser.enterStruct();
            }
            // Should succeed - we're at depth 500
        }

        @Test
        void rejectsExceeding500NestedStructsSerializer() {
            BcsSerializer ser = new BcsSerializer();
            // Enter 500 nested structs
            for (int i = 0; i < 500; i++) {
                ser.enterStruct();
            }
            // 501st should fail
            BcsError error = assertThrows(BcsError.class, ser::enterStruct);
            assertEquals(BcsError.Type.EXCEEDED_CONTAINER_DEPTH, error.getType());
        }

        @Test
        void rejectsExceeding500NestedStructsDeserializer() {
            BcsDeserializer des = new BcsDeserializer(new byte[0]);
            // Enter 500 nested structs
            for (int i = 0; i < 500; i++) {
                des.enterStruct();
            }
            // 501st should fail
            BcsError error = assertThrows(BcsError.class, des::enterStruct);
            assertEquals(BcsError.Type.EXCEEDED_CONTAINER_DEPTH, error.getType());
        }

        @Test
        void allowsUpTo500NestedEnumsSerializer() {
            BcsSerializer ser = new BcsSerializer();
            // Enter 500 nested enums (at max depth)
            for (int i = 0; i < 500; i++) {
                ser.enterEnum(0);
            }
            // Should succeed - we're at depth 500
        }

        @Test
        void rejectsExceeding500NestedEnumsSerializer() {
            BcsSerializer ser = new BcsSerializer();
            // Enter 500 nested enums
            for (int i = 0; i < 500; i++) {
                ser.enterEnum(0);
            }
            // 501st should fail
            BcsError error = assertThrows(BcsError.class, () -> ser.enterEnum(0));
            assertEquals(BcsError.Type.EXCEEDED_CONTAINER_DEPTH, error.getType());
        }
    }

    // ==========================================================================
    // ROUND-TRIP TESTS
    // ==========================================================================

    @Nested
    @DisplayName("Round-trip tests")
    class RoundTripTests {

        @Test
        void complexStruct() {
            // Simulate a Transfer struct: sender (32 bytes), recipient (32 bytes), amount (u64)
            byte[] sender = new byte[32];
            sender[31] = 1;
            byte[] recipient = new byte[32];
            recipient[31] = 2;
            long amount = 1000000L;

            BcsSerializer ser = new BcsSerializer();
            ser.enterStruct("Transfer");
            ser.writeFixedBytes(sender, 32);
            ser.writeFixedBytes(recipient, 32);
            ser.writeU64(amount);
            ser.leaveStruct();
            byte[] data = ser.toBytes();

            BcsDeserializer des = new BcsDeserializer(data);
            des.enterStruct("Transfer");
            byte[] readSender = des.readFixedBytes(32);
            byte[] readRecipient = des.readFixedBytes(32);
            long readAmount = des.readU64();
            des.leaveStruct();
            des.checkEnd();

            assertArrayEquals(sender, readSender);
            assertArrayEquals(recipient, readRecipient);
            assertEquals(amount, readAmount);
        }

        @Test
        void nestedVectors() {
            List<List<Short>> values = List.of(
                    List.of((short) 1, (short) 2),
                    List.of((short) 3, (short) 4, (short) 5));

            BcsSerializer ser = new BcsSerializer();
            ser.writeVector(values, (s, inner) -> s.writeVector(inner, (s2, v) -> s2.writeU8(v)));
            byte[] data = ser.toBytes();

            BcsDeserializer des = new BcsDeserializer(data);
            List<List<Short>> result = des.readVector(d -> d.readVector(BcsDeserializer::readU8));
            des.checkEnd();

            assertEquals(values, result);
        }
    }
}
