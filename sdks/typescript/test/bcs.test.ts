import { describe, it, expect, beforeAll } from "vitest";
import * as fs from "fs";
import * as path from "path";

import { BcsSerializer, BcsDeserializer, BcsError, hexToBytes, bytesToHex, uleb128 } from "../src";

// Load test vectors
const TEST_VECTORS_PATH = process.env.TEST_VECTORS || "../../test-vectors";
let testVectors: Record<string, unknown> = {};

beforeAll(() => {
  const vectorsPath = path.join(TEST_VECTORS_PATH, "bcs-comprehensive.json");
  if (fs.existsSync(vectorsPath)) {
    testVectors = JSON.parse(fs.readFileSync(vectorsPath, "utf-8"));
  }
});

function getTestVectors(path: string[]): Array<Record<string, unknown>> {
  let current: unknown = testVectors;
  for (const key of path) {
    if (current && typeof current === "object" && key in current) {
      current = (current as Record<string, unknown>)[key];
    } else {
      return [];
    }
  }
  return Array.isArray(current) ? current : [];
}

// ==========================================================================
// BOOLEAN TESTS
// ==========================================================================

describe("boolean serialization", () => {
  it("serialize true", () => {
    const ser = new BcsSerializer();
    ser.writeBool(true);
    expect(bytesToHex(ser.toBytes())).toBe("01");
  });

  it("serialize false", () => {
    const ser = new BcsSerializer();
    ser.writeBool(false);
    expect(bytesToHex(ser.toBytes())).toBe("00");
  });

  it("deserialize true", () => {
    const des = new BcsDeserializer(hexToBytes("01"));
    expect(des.readBool()).toBe(true);
  });

  it("deserialize false", () => {
    const des = new BcsDeserializer(hexToBytes("00"));
    expect(des.readBool()).toBe(false);
  });

  it("reject invalid boolean 0x02", () => {
    const des = new BcsDeserializer(hexToBytes("02"));
    expect(() => des.readBool()).toThrow(BcsError);
    try {
      const des2 = new BcsDeserializer(hexToBytes("02"));
      des2.readBool();
    } catch (e) {
      expect((e as BcsError).type).toBe("INVALID_BOOLEAN");
    }
  });
});

// ==========================================================================
// UNSIGNED INTEGER TESTS
// ==========================================================================

describe("u8 serialization", () => {
  const vectors = getTestVectors(["primitives", "u8", "valid"]);

  it("basic u8 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeU8(42);
    expect(bytesToHex(ser.toBytes())).toBe("2a");
    const des = new BcsDeserializer(hexToBytes("2a"));
    expect(des.readU8()).toBe(42);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeU8(tc.value as number);
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readU8()).toBe(tc.value);
    });
  }
});

describe("u16 serialization", () => {
  const vectors = getTestVectors(["primitives", "u16", "valid"]);

  it("basic u16 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeU16(0x1234);
    expect(bytesToHex(ser.toBytes())).toBe("3412");
    const des = new BcsDeserializer(hexToBytes("3412"));
    expect(des.readU16()).toBe(0x1234);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeU16(tc.value as number);
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readU16()).toBe(tc.value);
    });
  }
});

describe("u32 serialization", () => {
  const vectors = getTestVectors(["primitives", "u32", "valid"]);

  it("basic u32 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeU32(0x12345678);
    expect(bytesToHex(ser.toBytes())).toBe("78563412");
    const des = new BcsDeserializer(hexToBytes("78563412"));
    expect(des.readU32()).toBe(0x12345678);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeU32(tc.value as number);
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readU32()).toBe(tc.value);
    });
  }
});

describe("u64 serialization", () => {
  const vectors = getTestVectors(["primitives", "u64", "valid"]);

  it("basic u64 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeU64(0x123456789abcdef0n);
    expect(bytesToHex(ser.toBytes())).toBe("f0debc9a78563412");
    const des = new BcsDeserializer(hexToBytes("f0debc9a78563412"));
    expect(des.readU64()).toBe(0x123456789abcdef0n);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeU64(BigInt(tc.value as string));
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readU64()).toBe(BigInt(tc.value as string));
    });
  }
});

describe("u128 serialization", () => {
  const vectors = getTestVectors(["primitives", "u128", "valid"]);

  it("basic u128 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeU128(1n);
    const bytes = ser.toBytes();
    expect(bytes.length).toBe(16);
    expect(bytes[0]).toBe(1);
    const des = new BcsDeserializer(bytes);
    expect(des.readU128()).toBe(1n);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeU128(BigInt(tc.value as string));
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readU128()).toBe(BigInt(tc.value as string));
    });
  }
});

describe("u256 serialization", () => {
  const vectors = getTestVectors(["primitives", "u256", "valid"]);

  it("basic u256 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeU256(1n);
    const bytes = ser.toBytes();
    expect(bytes.length).toBe(32);
    expect(bytes[0]).toBe(1);
    const des = new BcsDeserializer(bytes);
    expect(des.readU256()).toBe(1n);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeU256(BigInt(tc.value as string));
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readU256()).toBe(BigInt(tc.value as string));
    });
  }
});

// ==========================================================================
// SIGNED INTEGER TESTS
// ==========================================================================

describe("i8 serialization", () => {
  const vectors = getTestVectors(["primitives", "i8", "valid"]);

  it("basic i8 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeI8(-1);
    expect(bytesToHex(ser.toBytes())).toBe("ff");
    const des = new BcsDeserializer(hexToBytes("ff"));
    expect(des.readI8()).toBe(-1);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeI8(tc.value as number);
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readI8()).toBe(tc.value);
    });
  }
});

describe("i16 serialization", () => {
  const vectors = getTestVectors(["primitives", "i16", "valid"]);

  it("basic i16 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeI16(-1);
    expect(bytesToHex(ser.toBytes())).toBe("ffff");
    const des = new BcsDeserializer(hexToBytes("ffff"));
    expect(des.readI16()).toBe(-1);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeI16(tc.value as number);
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readI16()).toBe(tc.value);
    });
  }
});

describe("i32 serialization", () => {
  const vectors = getTestVectors(["primitives", "i32", "valid"]);

  it("basic i32 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeI32(-1);
    expect(bytesToHex(ser.toBytes())).toBe("ffffffff");
    const des = new BcsDeserializer(hexToBytes("ffffffff"));
    expect(des.readI32()).toBe(-1);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeI32(tc.value as number);
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readI32()).toBe(tc.value);
    });
  }
});

describe("i64 serialization", () => {
  const vectors = getTestVectors(["primitives", "i64", "valid"]);

  it("basic i64 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeI64(-1n);
    expect(bytesToHex(ser.toBytes())).toBe("ffffffffffffffff");
    const des = new BcsDeserializer(hexToBytes("ffffffffffffffff"));
    expect(des.readI64()).toBe(-1n);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeI64(BigInt(tc.value as string));
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readI64()).toBe(BigInt(tc.value as string));
    });
  }
});

describe("i128 serialization", () => {
  const vectors = getTestVectors(["primitives", "i128", "valid"]);

  it("basic i128 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeI128(-1n);
    expect(bytesToHex(ser.toBytes())).toBe("ffffffffffffffffffffffffffffffff");
    const des = new BcsDeserializer(hexToBytes("ffffffffffffffffffffffffffffffff"));
    expect(des.readI128()).toBe(-1n);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeI128(BigInt(tc.value as string));
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readI128()).toBe(BigInt(tc.value as string));
    });
  }
});

describe("i256 serialization", () => {
  const vectors = getTestVectors(["primitives", "i256", "valid"]);

  it("basic i256 round-trip", () => {
    const ser = new BcsSerializer();
    ser.writeI256(-1n);
    expect(bytesToHex(ser.toBytes())).toBe("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
    const des = new BcsDeserializer(hexToBytes("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"));
    expect(des.readI256()).toBe(-1n);
  });

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeI256(BigInt(tc.value as string));
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readI256()).toBe(BigInt(tc.value as string));
    });
  }
});

// ==========================================================================
// ULEB128 TESTS
// ==========================================================================

describe("ULEB128 encoding", () => {
  const vectors = getTestVectors(["uleb128", "valid"]);

  for (const tc of vectors) {
    it(`encode ${tc.name}`, () => {
      const encoded = uleb128.encode(tc.value as number);
      expect(bytesToHex(encoded)).toBe(tc.bcs_hex);
    });

    it(`decode ${tc.name}`, () => {
      const [value, bytesRead] = uleb128.decode(hexToBytes(tc.bcs_hex as string));
      expect(value).toBe(tc.value);
    });
  }

  it("reject non-canonical encoding", () => {
    // 0x80 0x00 is non-canonical for 0
    expect(() => uleb128.decode(new Uint8Array([0x80, 0x00]))).toThrow(BcsError);
  });

  it("reject overflow", () => {
    // 6 bytes with continuation bits
    expect(() => uleb128.decode(new Uint8Array([0x80, 0x80, 0x80, 0x80, 0x80, 0x01]))).toThrow(
      BcsError
    );
  });
});

// ==========================================================================
// STRING TESTS
// ==========================================================================

describe("string serialization", () => {
  const vectors = getTestVectors(["strings", "valid"]);

  for (const tc of vectors) {
    it(`serialize ${tc.name}`, () => {
      const ser = new BcsSerializer();
      ser.writeString(tc.value as string);
      expect(bytesToHex(ser.toBytes())).toBe(tc.bcs_hex);
    });

    it(`deserialize ${tc.name}`, () => {
      const des = new BcsDeserializer(hexToBytes(tc.bcs_hex as string));
      expect(des.readString()).toBe(tc.value);
    });
  }

  it("reject invalid UTF-8", () => {
    // Length 1, byte 0xFF (invalid UTF-8)
    const des = new BcsDeserializer(new Uint8Array([1, 0xff]));
    expect(() => des.readString()).toThrow(BcsError);
  });
});

// ==========================================================================
// OPTION TESTS
// ==========================================================================

describe("option serialization", () => {
  it("serialize None", () => {
    const ser = new BcsSerializer();
    ser.writeOption(null, (s, v: number) => s.writeU8(v));
    expect(bytesToHex(ser.toBytes())).toBe("00");
  });

  it("serialize Some(42)", () => {
    const ser = new BcsSerializer();
    ser.writeOption(42, (s, v) => s.writeU8(v));
    expect(bytesToHex(ser.toBytes())).toBe("012a");
  });

  it("deserialize None", () => {
    const des = new BcsDeserializer(hexToBytes("00"));
    expect(des.readOption((d) => d.readU8())).toBe(null);
  });

  it("deserialize Some(42)", () => {
    const des = new BcsDeserializer(hexToBytes("012a"));
    expect(des.readOption((d) => d.readU8())).toBe(42);
  });

  it("reject invalid option tag", () => {
    const des = new BcsDeserializer(hexToBytes("02"));
    expect(() => des.readOption((d) => d.readU8())).toThrow(BcsError);
  });
});

// ==========================================================================
// VECTOR TESTS
// ==========================================================================

describe("vector serialization", () => {
  it("serialize empty vector", () => {
    const ser = new BcsSerializer();
    ser.writeVector([], (s, v: number) => s.writeU8(v));
    expect(bytesToHex(ser.toBytes())).toBe("00");
  });

  it("serialize [1, 2, 3]", () => {
    const ser = new BcsSerializer();
    ser.writeVector([1, 2, 3], (s, v) => s.writeU8(v));
    expect(bytesToHex(ser.toBytes())).toBe("03010203");
  });

  it("deserialize empty vector", () => {
    const des = new BcsDeserializer(hexToBytes("00"));
    expect(des.readVector((d) => d.readU8())).toEqual([]);
  });

  it("deserialize [1, 2, 3]", () => {
    const des = new BcsDeserializer(hexToBytes("03010203"));
    expect(des.readVector((d) => d.readU8())).toEqual([1, 2, 3]);
  });

  it("reject vector with length exceeding data", () => {
    const des = new BcsDeserializer(hexToBytes("05010203"));
    expect(() => des.readVector((d) => d.readU8())).toThrow(BcsError);
  });
});

// ==========================================================================
// MAP TESTS
// ==========================================================================

describe("map serialization", () => {
  it("serialize empty map", () => {
    const ser = new BcsSerializer();
    ser.writeMap(
      new Map(),
      (s, k: number) => s.writeU8(k),
      (s, v: number) => s.writeU8(v)
    );
    expect(bytesToHex(ser.toBytes())).toBe("00");
  });

  it("serialize single entry map", () => {
    const ser = new BcsSerializer();
    ser.writeMap(
      new Map([[1, 10]]),
      (s, k) => s.writeU8(k),
      (s, v) => s.writeU8(v)
    );
    expect(bytesToHex(ser.toBytes())).toBe("01010a");
  });

  it("serialize sorted map", () => {
    const ser = new BcsSerializer();
    // Keys should be serialized in sorted order by BCS bytes
    ser.writeMap(
      new Map([
        [3, 40],
        [1, 10],
        [2, 20],
      ]),
      (s, k) => s.writeU8(k),
      (s, v) => s.writeU8(v)
    );
    expect(bytesToHex(ser.toBytes())).toBe("03010a02140328");
  });

  it("deserialize empty map", () => {
    const des = new BcsDeserializer(hexToBytes("00"));
    const result = des.readMap(
      (d) => d.readU8(),
      (d) => d.readU8()
    );
    expect(result.size).toBe(0);
  });

  it("deserialize map with entries", () => {
    const des = new BcsDeserializer(hexToBytes("03010a02140328"));
    const result = des.readMap(
      (d) => d.readU8(),
      (d) => d.readU8()
    );
    expect(result.size).toBe(3);
    expect(result.get(1)).toBe(10);
    expect(result.get(2)).toBe(20);
    expect(result.get(3)).toBe(40);  // 0x28 = 40
  });

  it("reject unsorted map keys", () => {
    // Keys are [2, 1] which is not sorted
    const des = new BcsDeserializer(hexToBytes("0302140110"));
    expect(() =>
      des.readMap(
        (d) => d.readU8(),
        (d) => d.readU8()
      )
    ).toThrow(BcsError);
  });

  it("reject duplicate map keys", () => {
    // Keys [1, 1] are duplicates
    const des = new BcsDeserializer(hexToBytes("0201100110"));
    expect(() =>
      des.readMap(
        (d) => d.readU8(),
        (d) => d.readU8()
      )
    ).toThrow(BcsError);
  });
});

// ==========================================================================
// ERROR CASE TESTS
// ==========================================================================

describe("error cases", () => {
  it("remaining input", () => {
    const des = new BcsDeserializer(hexToBytes("0001"));
    des.readBool();
    expect(() => des.checkEnd()).toThrow(BcsError);
  });

  it("unexpected EOF on u64", () => {
    const des = new BcsDeserializer(hexToBytes("010203"));
    expect(() => des.readU64()).toThrow(BcsError);
  });

  it("unexpected EOF on empty input", () => {
    const des = new BcsDeserializer(new Uint8Array(0));
    expect(() => des.readU8()).toThrow(BcsError);
  });
});

// ==========================================================================
// ROUND-TRIP TESTS
// ==========================================================================

describe("round-trip", () => {
  it("complex struct", () => {
    // Simulate a Transfer struct: sender (32 bytes), recipient (32 bytes), amount (u64)
    const sender = new Uint8Array(32);
    sender[31] = 1;
    const recipient = new Uint8Array(32);
    recipient[31] = 2;
    const amount = 1000000n;

    const ser = new BcsSerializer();
    ser.writeFixedBytes(sender, 32);
    ser.writeFixedBytes(recipient, 32);
    ser.writeU64(amount);
    const data = ser.toBytes();

    const des = new BcsDeserializer(data);
    const readSender = des.readFixedBytes(32);
    const readRecipient = des.readFixedBytes(32);
    const readAmount = des.readU64();
    des.checkEnd();

    expect(readSender).toEqual(sender);
    expect(readRecipient).toEqual(recipient);
    expect(readAmount).toBe(amount);
  });

  it("nested vectors", () => {
    const values = [
      [1, 2],
      [3, 4, 5],
    ];

    const ser = new BcsSerializer();
    ser.writeVector(values, (s, inner) => {
      s.writeVector(inner, (s2, v) => s2.writeU8(v));
    });
    const data = ser.toBytes();

    const des = new BcsDeserializer(data);
    const result = des.readVector((d) => d.readVector((d2) => d2.readU8()));
    des.checkEnd();

    expect(result).toEqual(values);
  });
});

// ==========================================================================
// CONTAINER DEPTH TESTS
// ==========================================================================

describe("container depth", () => {
  it("serializer tracks struct depth", () => {
    const ser = new BcsSerializer();
    expect(ser.containerDepth).toBe(0);
    
    ser.enterStruct();
    expect(ser.containerDepth).toBe(1);
    
    ser.enterStruct();
    expect(ser.containerDepth).toBe(2);
    
    ser.leaveStruct();
    expect(ser.containerDepth).toBe(1);
    
    ser.leaveStruct();
    expect(ser.containerDepth).toBe(0);
  });

  it("serializer tracks enum depth", () => {
    const ser = new BcsSerializer();
    expect(ser.containerDepth).toBe(0);
    
    ser.enterEnum(0);
    expect(ser.containerDepth).toBe(1);
    
    ser.leaveEnum();
    expect(ser.containerDepth).toBe(0);
  });

  it("deserializer tracks struct depth", () => {
    const des = new BcsDeserializer(new Uint8Array(0));
    expect(des.containerDepth).toBe(0);
    
    des.enterStruct();
    expect(des.containerDepth).toBe(1);
    
    des.enterStruct();
    expect(des.containerDepth).toBe(2);
    
    des.leaveStruct();
    expect(des.containerDepth).toBe(1);
    
    des.leaveStruct();
    expect(des.containerDepth).toBe(0);
  });

  it("deserializer enterEnum reads variant index", () => {
    // Create data with ULEB128-encoded variant index 5
    const ser = new BcsSerializer();
    ser.writeVariantIndex(5);
    const data = ser.toBytes();
    
    const des = new BcsDeserializer(data);
    const variantIndex = des.enterEnum();
    expect(variantIndex).toBe(5);
    expect(des.containerDepth).toBe(1);
    
    des.leaveEnum();
    expect(des.containerDepth).toBe(0);
  });

  it("serializer rejects depth exceeding 500", () => {
    const ser = new BcsSerializer();
    
    // Enter 500 structs (at the limit)
    for (let i = 0; i < 500; i++) {
      ser.enterStruct();
    }
    expect(ser.containerDepth).toBe(500);
    
    // 501st should fail
    expect(() => ser.enterStruct()).toThrow(BcsError);
  });

  it("deserializer rejects depth exceeding 500", () => {
    const des = new BcsDeserializer(new Uint8Array(0));
    
    // Enter 500 structs (at the limit)
    for (let i = 0; i < 500; i++) {
      des.enterStruct();
    }
    expect(des.containerDepth).toBe(500);
    
    // 501st should fail
    expect(() => des.enterStruct()).toThrow(BcsError);
  });
});
