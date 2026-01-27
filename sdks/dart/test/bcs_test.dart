import 'dart:typed_data';

import 'package:bcs/bcs.dart';
import 'package:test/test.dart';

void main() {
  // ============================================================================
  // ULEB128 Tests
  // ============================================================================

  group('Uleb128', () {
    test('encode', () {
      expect(Uleb128.encode(0), equals([0x00]));
      expect(Uleb128.encode(1), equals([0x01]));
      expect(Uleb128.encode(127), equals([0x7f]));
      expect(Uleb128.encode(128), equals([0x80, 0x01]));
      expect(Uleb128.encode(255), equals([0xff, 0x01]));
      expect(Uleb128.encode(300), equals([0xac, 0x02]));
      expect(Uleb128.encode(16384), equals([0x80, 0x80, 0x01]));
      expect(
        Uleb128.encode(0xFFFFFFFF),
        equals([0xff, 0xff, 0xff, 0xff, 0x0f]),
      );
    });

    test('decode', () {
      expect(
        Uleb128.decode(Uint8List.fromList([0x00])),
        equals((value: 0, bytesRead: 1)),
      );
      expect(
        Uleb128.decode(Uint8List.fromList([0x7f])),
        equals((value: 127, bytesRead: 1)),
      );
      expect(
        Uleb128.decode(Uint8List.fromList([0x80, 0x01])),
        equals((value: 128, bytesRead: 2)),
      );
      expect(
        Uleb128.decode(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x0f])),
        equals((value: 0xFFFFFFFF, bytesRead: 5)),
      );
    });

    test('reject non-canonical', () {
      expect(
        () => Uleb128.decode(Uint8List.fromList([0x80, 0x00])),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.nonCanonicalUleb128,
          ),
        ),
      );
    });

    test('reject overflow', () {
      expect(
        () =>
            Uleb128.decode(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x1f])),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.uleb128Overflow,
          ),
        ),
      );
    });
  });

  // ============================================================================
  // Boolean Tests
  // ============================================================================

  group('Bool', () {
    test('serialize', () {
      expect(BcsSerializer().writeBool(true).toBytes(), equals([0x01]));
      expect(BcsSerializer().writeBool(false).toBytes(), equals([0x00]));
    });

    test('deserialize', () {
      expect(BcsDeserializer.fromList([0x01]).readBool(), isTrue);
      expect(BcsDeserializer.fromList([0x00]).readBool(), isFalse);
    });

    test('invalid value', () {
      expect(
        () => BcsDeserializer.fromList([0x02]).readBool(),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.invalidBoolean,
          ),
        ),
      );
    });
  });

  // ============================================================================
  // Integer Tests
  // ============================================================================

  group('Integers', () {
    test('u8 serialization', () {
      expect(BcsSerializer().writeU8(0).toBytes(), equals([0x00]));
      expect(BcsSerializer().writeU8(255).toBytes(), equals([0xff]));
      expect(BcsSerializer().writeU8(42).toBytes(), equals([0x2a]));
    });

    test('u16 serialization', () {
      expect(BcsSerializer().writeU16(0).toBytes(), equals([0x00, 0x00]));
      expect(BcsSerializer().writeU16(0x1234).toBytes(), equals([0x34, 0x12]));
      expect(BcsSerializer().writeU16(0xFFFF).toBytes(), equals([0xff, 0xff]));
    });

    test('u32 serialization', () {
      expect(
        BcsSerializer().writeU32(0).toBytes(),
        equals([0x00, 0x00, 0x00, 0x00]),
      );
      expect(
        BcsSerializer().writeU32(0x12345678).toBytes(),
        equals([0x78, 0x56, 0x34, 0x12]),
      );
    });

    test('u64 serialization', () {
      expect(
        BcsSerializer().writeU64(BigInt.zero).toBytes(),
        equals([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
      );
      expect(
        BcsSerializer()
            .writeU64(BigInt.parse('123456789ABCDEF0', radix: 16))
            .toBytes(),
        equals([0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12]),
      );
    });

    test('i8 serialization', () {
      expect(BcsSerializer().writeI8(-1).toBytes(), equals([0xff]));
      expect(BcsSerializer().writeI8(-128).toBytes(), equals([0x80]));
      expect(BcsSerializer().writeI8(127).toBytes(), equals([0x7f]));
    });

    test('i16 serialization', () {
      expect(BcsSerializer().writeI16(-1).toBytes(), equals([0xff, 0xff]));
      expect(BcsSerializer().writeI16(-32768).toBytes(), equals([0x00, 0x80]));
    });

    test('i32 serialization', () {
      expect(
        BcsSerializer().writeI32(-1).toBytes(),
        equals([0xff, 0xff, 0xff, 0xff]),
      );
      expect(
        BcsSerializer().writeI32(2147483647).toBytes(),
        equals([0xff, 0xff, 0xff, 0x7f]),
      );
      expect(
        BcsSerializer().writeI32(-2147483648).toBytes(),
        equals([0x00, 0x00, 0x00, 0x80]),
      );
    });

    test('i64 serialization', () {
      expect(
        BcsSerializer().writeI64(BigInt.from(-1)).toBytes(),
        equals([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
      );
      expect(
        BcsSerializer()
            .writeI64(BigInt.parse('9223372036854775807'))
            .toBytes(),
        equals([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f]),
      );
      expect(
        BcsSerializer()
            .writeI64(BigInt.parse('-9223372036854775808'))
            .toBytes(),
        equals([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]),
      );
    });

    test('i128 serialization', () {
      // -1 in two's complement (all 0xff bytes)
      final negOne = BcsSerializer().writeI128(BigInt.from(-1)).toBytes();
      expect(negOne.length, equals(16));
      for (final b in negOne) {
        expect(b, equals(0xff));
      }
    });

    test('integer deserialization', () {
      expect(BcsDeserializer.fromList([0x2a]).readU8(), equals(42));
      expect(BcsDeserializer.fromList([0x34, 0x12]).readU16(), equals(0x1234));
      expect(
        BcsDeserializer.fromList([0x78, 0x56, 0x34, 0x12]).readU32(),
        equals(0x12345678),
      );
      expect(
        BcsDeserializer.fromList([
          0xf0,
          0xde,
          0xbc,
          0x9a,
          0x78,
          0x56,
          0x34,
          0x12,
        ]).readU64(),
        equals(BigInt.parse('123456789ABCDEF0', radix: 16)),
      );
    });

    test('signed integer deserialization', () {
      expect(BcsDeserializer.fromList([0xff]).readI8(), equals(-1));
      expect(BcsDeserializer.fromList([0x00, 0x80]).readI16(), equals(-32768));
    });

    test('i32 deserialization', () {
      expect(
        BcsDeserializer.fromList([0xff, 0xff, 0xff, 0xff]).readI32(),
        equals(-1),
      );
      expect(
        BcsDeserializer.fromList([0x00, 0x00, 0x00, 0x80]).readI32(),
        equals(-2147483648),
      );
    });

    test('i64 deserialization', () {
      expect(
        BcsDeserializer.fromList(
          [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
        ).readI64(),
        equals(BigInt.from(-1)),
      );
      expect(
        BcsDeserializer.fromList(
          [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80],
        ).readI64(),
        equals(BigInt.parse('-9223372036854775808')),
      );
    });

    test('i128 deserialization', () {
      final allFf = List.filled(16, 0xff);
      expect(
        BcsDeserializer.fromList(allFf).readI128(),
        equals(BigInt.from(-1)),
      );
    });
  });

  // ============================================================================
  // u128/u256 Tests
  // ============================================================================

  group('Large Integers', () {
    test('u128 serialization', () {
      final ser = BcsSerializer()..writeU128(BigInt.one);
      final bytes = ser.toBytes();
      expect(bytes.length, equals(16));
      expect(bytes[0], equals(0x01));
      for (var i = 1; i < 16; i++) {
        expect(bytes[i], equals(0));
      }
    });

    test('u256 serialization', () {
      final ser = BcsSerializer();
      final value = (BigInt.one << 255) + BigInt.from(0xff);
      ser.writeU256(value);
      final bytes = ser.toBytes();
      expect(bytes.length, equals(32));
      expect(bytes[0], equals(0xff));
      expect(bytes[31], equals(0x80));
    });

    test('round trip u128', () {
      final original = BigInt.parse(
        '123456789ABCDEF0123456789ABCDEF0',
        radix: 16,
      );
      final bytes = BcsSerializer().writeU128(original).toBytes();
      final result = BcsDeserializer(bytes).readU128();
      expect(result, equals(original));
    });
  });

  // ============================================================================
  // String Tests
  // ============================================================================

  group('String', () {
    test('serialize', () {
      expect(BcsSerializer().writeString('').toBytes(), equals([0x00]));
      expect(
        BcsSerializer().writeString('hello').toBytes(),
        equals([0x05, 0x68, 0x65, 0x6c, 0x6c, 0x6f]),
      );
    });

    test('deserialize', () {
      expect(BcsDeserializer.fromList([0x00]).readString(), equals(''));
      expect(
        BcsDeserializer.fromList([
          0x05,
          0x68,
          0x65,
          0x6c,
          0x6c,
          0x6f,
        ]).readString(),
        equals('hello'),
      );
    });

    test('invalid UTF-8', () {
      expect(
        () => BcsDeserializer.fromList([0x02, 0xff, 0xfe]).readString(),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.invalidUtf8,
          ),
        ),
      );
    });
  });

  // ============================================================================
  // Bytes Tests
  // ============================================================================

  group('Bytes', () {
    test('serialize', () {
      final bytes = BcsSerializer()
          .writeBytes(Uint8List.fromList([0x01, 0x02, 0x03]))
          .toBytes();
      expect(bytes, equals([0x03, 0x01, 0x02, 0x03]));
    });

    test('deserialize', () {
      final bytes = BcsDeserializer.fromList([
        0x03,
        0x01,
        0x02,
        0x03,
      ]).readBytes();
      expect(bytes, equals([0x01, 0x02, 0x03]));
    });
  });

  // ============================================================================
  // Option Tests
  // ============================================================================

  group('Option', () {
    test('some serialization', () {
      final bytes = BcsSerializer()
          .writeOption<int>(42, (s, v) => s.writeU8(v))
          .toBytes();
      expect(bytes, equals([0x01, 0x2a]));
    });

    test('none serialization', () {
      final bytes = BcsSerializer()
          .writeOption<int>(null, (s, v) => s.writeU8(v))
          .toBytes();
      expect(bytes, equals([0x00]));
    });

    test('some deserialization', () {
      final opt = BcsDeserializer.fromList([
        0x01,
        0x2a,
      ]).readOption((d) => d.readU8());
      expect(opt, equals(42));
    });

    test('none deserialization', () {
      final opt = BcsDeserializer.fromList([
        0x00,
      ]).readOption((d) => d.readU8());
      expect(opt, isNull);
    });

    test('invalid tag', () {
      expect(
        () => BcsDeserializer.fromList([0x02]).readOption((d) => d.readU8()),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.invalidOption,
          ),
        ),
      );
    });
  });

  // ============================================================================
  // Vector Tests
  // ============================================================================

  group('Vector', () {
    test('empty serialization', () {
      final bytes = BcsSerializer()
          .writeVector<int>([], (s, v) => s.writeU8(v)).toBytes();
      expect(bytes, equals([0x00]));
    });

    test('u8 serialization', () {
      final bytes = BcsSerializer()
          .writeVector<int>([1, 2, 3], (s, v) => s.writeU8(v)).toBytes();
      expect(bytes, equals([0x03, 0x01, 0x02, 0x03]));
    });

    test('u16 serialization', () {
      final bytes = BcsSerializer()
          .writeVector<int>([1, 2, 3], (s, v) => s.writeU16(v)).toBytes();
      expect(bytes, equals([0x03, 0x01, 0x00, 0x02, 0x00, 0x03, 0x00]));
    });

    test('deserialization', () {
      final vec = BcsDeserializer.fromList([
        0x03,
        0x01,
        0x02,
        0x03,
      ]).readVector((d) => d.readU8());
      expect(vec, equals([1, 2, 3]));
    });
  });

  // ============================================================================
  // Map Tests
  // ============================================================================

  group('Map', () {
    test('deserialization', () {
      // 3 entries: (1, 10), (2, 20), (3, 30)
      final map = BcsDeserializer.fromList([
        0x03,
        0x01,
        0x0a,
        0x02,
        0x14,
        0x03,
        0x1e,
      ]).readMap((d) => d.readU8(), (d) => d.readU8());

      expect(map.length, equals(3));
      expect(map[1], equals(10));
      expect(map[2], equals(20));
      expect(map[3], equals(30));
    });

    test('non-canonical order', () {
      // Keys out of order: 2, 1
      expect(
        () => BcsDeserializer.fromList([
          0x02,
          0x02,
          0x14,
          0x01,
          0x0a,
        ]).readMap((d) => d.readU8(), (d) => d.readU8()),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.nonCanonicalMap,
          ),
        ),
      );
    });

    test('duplicate keys', () {
      // Duplicate key: 1, 1
      expect(
        () => BcsDeserializer.fromList([
          0x02,
          0x01,
          0x0a,
          0x01,
          0x14,
        ]).readMap((d) => d.readU8(), (d) => d.readU8()),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.duplicateMapKey,
          ),
        ),
      );
    });
  });

  // ============================================================================
  // Error Handling Tests
  // ============================================================================

  group('Errors', () {
    test('unexpected EOF', () {
      // Only 1 byte, need 2 for u16
      expect(
        () => BcsDeserializer.fromList([0x01]).readU16(),
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.unexpectedEof,
          ),
        ),
      );
    });

    test('remaining input', () {
      final des = BcsDeserializer.fromList([0x01, 0x02])
        ..readU8(); // Extra byte
      expect(
        des.checkEnd,
        throwsA(
          isA<BcsError>().having(
            (e) => e.type,
            'type',
            BcsErrorType.remainingInput,
          ),
        ),
      );
    });
  });

  // ============================================================================
  // Round-trip Tests
  // ============================================================================

  group('Round-trip', () {
    test('u64', () {
      final original = BigInt.parse('123456789ABCDEF0', radix: 16);
      final bytes = BcsSerializer().writeU64(original).toBytes();
      final result = BcsDeserializer(bytes).readU64();
      expect(result, equals(original));
    });

    test('string', () {
      final original = 'Hello, BCS! 你好世界';
      final bytes = BcsSerializer().writeString(original).toBytes();
      final result = BcsDeserializer(bytes).readString();
      expect(result, equals(original));
    });

    test('complex', () {
      // Serialize: (u8, string, vector<u16>)
      final ser = BcsSerializer()
        ..writeU8(42)
        ..writeString('test')
        ..writeVector<int>([100, 200, 300], (s, v) => s.writeU16(v));
      final bytes = ser.toBytes();

      // Deserialize
      final des = BcsDeserializer(bytes);
      expect(des.readU8(), equals(42));
      expect(des.readString(), equals('test'));
      expect(des.readVector((d) => d.readU16()), equals([100, 200, 300]));
      des.checkEnd();
    });
  });

  // ============================================================================
  // Hex Utilities
  // ============================================================================

  group('Hex Utilities', () {
    test('bytes to hex', () {
      expect(
        bytesToHex(Uint8List.fromList([0x01, 0x02, 0xab, 0xcd])),
        equals('0102abcd'),
      );
    });

    test('hex to bytes', () {
      expect(hexToBytes('0102abcd'), equals([0x01, 0x02, 0xab, 0xcd]));
    });
  });

  // ============================================================================
  // Container Depth Tests
  // ============================================================================

  group('Container Depth', () {
    test('struct depth tracking', () {
      final ser = BcsSerializer()
        ..enterStruct('Test')
        ..writeU8(42)
        ..leaveStruct();
      expect(ser.toBytes(), equals([42]));
    });

    test('enum depth tracking', () {
      final ser = BcsSerializer()
        ..enterEnum(1)
        ..writeU8(42)
        ..leaveEnum();
      expect(ser.toBytes(), equals([1, 42]));
    });
  });
}
