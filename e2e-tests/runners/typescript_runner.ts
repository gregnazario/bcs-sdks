#!/usr/bin/env npx tsx
/**
 * TypeScript BCS E2E Test Runner
 *
 * Reads test vectors from stdin, performs roundtrip serialization,
 * and outputs results to stdout.
 *
 * Supports two modes:
 * - Default: Roundtrip testing for correctness
 * - Benchmark (--benchmark): Performance timing
 */

import * as readline from "readline";
import * as path from "path";

const benchmarkMode = process.argv.includes("--benchmark");

// Import the BCS SDK (relative to the runner location)
const sdkPath = path.resolve(__dirname, "../../sdks/typescript/src");

// Dynamic import to handle the path
async function loadBcs() {
  const { BcsSerializer, BcsDeserializer } = await import(sdkPath + "/index");
  return { BcsSerializer, BcsDeserializer };
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

interface TestCase {
  name: string;
  type: string;
  value: any;
  bcs_hex: string;
  note?: string;
  error?: string;
}

interface TestVectors {
  version: string;
  description: string;
  primitives: TestCase[];
  strings: TestCase[];
  bytes: TestCase[];
  options: TestCase[];
  vectors: TestCase[];
  structs: TestCase[];
  complex: TestCase[];
}

async function main() {
  const { BcsSerializer, BcsDeserializer } = await loadBcs();

  // Read input from stdin
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false,
  });

  let inputData = "";
  for await (const line of rl) {
    inputData += line;
  }

  const vectors: TestVectors = JSON.parse(inputData);

  function processTestCase(testCase: TestCase): TestCase {
    const { name, type: typ, bcs_hex } = testCase;

    try {
      const data = hexToBytes(bcs_hex);
      let resultHex: string;

      if (typ === "bool") {
        const d = new BcsDeserializer(data);
        const value = d.readBool();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeBool(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "u8") {
        const d = new BcsDeserializer(data);
        const value = d.readU8();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeU8(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "u16") {
        const d = new BcsDeserializer(data);
        const value = d.readU16();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeU16(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "u32") {
        const d = new BcsDeserializer(data);
        const value = d.readU32();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeU32(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "u64") {
        const d = new BcsDeserializer(data);
        const value = d.readU64();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeU64(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "u128") {
        const d = new BcsDeserializer(data);
        const value = d.readU128();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeU128(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "i8") {
        const d = new BcsDeserializer(data);
        const value = d.readI8();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeI8(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "i16") {
        const d = new BcsDeserializer(data);
        const value = d.readI16();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeI16(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "i32") {
        const d = new BcsDeserializer(data);
        const value = d.readI32();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeI32(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "i64") {
        const d = new BcsDeserializer(data);
        const value = d.readI64();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeI64(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "i128") {
        const d = new BcsDeserializer(data);
        const value = d.readI128();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeI128(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "string") {
        const d = new BcsDeserializer(data);
        const value = d.readString();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeString(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "bytes") {
        const d = new BcsDeserializer(data);
        const value = d.readBytes();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeBytes(value);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "fixed_bytes_32") {
        const d = new BcsDeserializer(data);
        const value = d.readFixedBytes(32);
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeFixedBytes(value, 32);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "option<u8>") {
        const d = new BcsDeserializer(data);
        const hasValue = d.readBool();
        const s = new BcsSerializer();
        if (hasValue) {
          const value = d.readU8();
          d.checkEnd();
          s.writeBool(true);
          s.writeU8(value);
        } else {
          d.checkEnd();
          s.writeBool(false);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "option<u64>") {
        const d = new BcsDeserializer(data);
        const hasValue = d.readBool();
        const s = new BcsSerializer();
        if (hasValue) {
          const value = d.readU64();
          d.checkEnd();
          s.writeBool(true);
          s.writeU64(value);
        } else {
          d.checkEnd();
          s.writeBool(false);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "option<bool>") {
        const d = new BcsDeserializer(data);
        const hasValue = d.readBool();
        const s = new BcsSerializer();
        if (hasValue) {
          const value = d.readBool();
          d.checkEnd();
          s.writeBool(true);
          s.writeBool(value);
        } else {
          d.checkEnd();
          s.writeBool(false);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "option<string>") {
        const d = new BcsDeserializer(data);
        const hasValue = d.readBool();
        const s = new BcsSerializer();
        if (hasValue) {
          const value = d.readString();
          d.checkEnd();
          s.writeBool(true);
          s.writeString(value);
        } else {
          d.checkEnd();
          s.writeBool(false);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "vector<u8>") {
        const d = new BcsDeserializer(data);
        const len = d.readUleb128();
        const values: number[] = [];
        for (let i = 0; i < len; i++) {
          values.push(d.readU8());
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(values.length);
        for (const v of values) {
          s.writeU8(v);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "vector<u64>") {
        const d = new BcsDeserializer(data);
        const len = d.readUleb128();
        const values: bigint[] = [];
        for (let i = 0; i < len; i++) {
          values.push(d.readU64());
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(values.length);
        for (const v of values) {
          s.writeU64(v);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "vector<bool>") {
        const d = new BcsDeserializer(data);
        const len = d.readUleb128();
        const values: boolean[] = [];
        for (let i = 0; i < len; i++) {
          values.push(d.readBool());
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(values.length);
        for (const v of values) {
          s.writeBool(v);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "vector<vector<u8>>") {
        const d = new BcsDeserializer(data);
        const outerLen = d.readUleb128();
        const outer: number[][] = [];
        for (let i = 0; i < outerLen; i++) {
          const innerLen = d.readUleb128();
          const inner: number[] = [];
          for (let j = 0; j < innerLen; j++) {
            inner.push(d.readU8());
          }
          outer.push(inner);
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(outer.length);
        for (const inner of outer) {
          s.writeUleb128(inner.length);
          for (const v of inner) {
            s.writeU8(v);
          }
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "vector<string>") {
        const d = new BcsDeserializer(data);
        const len = d.readUleb128();
        const values: string[] = [];
        for (let i = 0; i < len; i++) {
          values.push(d.readString());
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(values.length);
        for (const v of values) {
          s.writeString(v);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "struct") {
        const fields = testCase.value.fields;
        const d = new BcsDeserializer(data);
        const values: Array<{ type: string; value: any }> = [];

        for (const field of fields) {
          if (field.type === "u8") {
            values.push({ type: "u8", value: d.readU8() });
          } else if (field.type === "u64") {
            values.push({ type: "u64", value: d.readU64() });
          } else if (field.type === "string") {
            values.push({ type: "string", value: d.readString() });
          } else if (field.type === "fixed_bytes_32") {
            values.push({ type: "fixed_bytes_32", value: d.readFixedBytes(32) });
          }
        }
        d.checkEnd();

        const s = new BcsSerializer();
        for (const v of values) {
          if (v.type === "u8") {
            s.writeU8(v.value);
          } else if (v.type === "u64") {
            s.writeU64(v.value);
          } else if (v.type === "string") {
            s.writeString(v.value);
          } else if (v.type === "fixed_bytes_32") {
            s.writeFixedBytes(v.value, 32);
          }
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "map<u8,u8>") {
        const d = new BcsDeserializer(data);
        const len = d.readUleb128();
        const pairs: Array<[number, number]> = [];
        for (let i = 0; i < len; i++) {
          const k = d.readU8();
          const v = d.readU8();
          pairs.push([k, v]);
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(pairs.length);
        for (const [k, v] of pairs) {
          s.writeU8(k);
          s.writeU8(v);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "map<string,u64>") {
        const d = new BcsDeserializer(data);
        const len = d.readUleb128();
        const pairs: Array<[string, bigint]> = [];
        for (let i = 0; i < len; i++) {
          const k = d.readString();
          const v = d.readU64();
          pairs.push([k, v]);
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(pairs.length);
        for (const [k, v] of pairs) {
          s.writeString(k);
          s.writeU64(v);
        }
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "tuple<u8,u64>") {
        const d = new BcsDeserializer(data);
        const a = d.readU8();
        const b = d.readU64();
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeU8(a);
        s.writeU64(b);
        resultHex = bytesToHex(s.toBytes());
      } else if (typ === "vector<option<u8>>") {
        const d = new BcsDeserializer(data);
        const len = d.readUleb128();
        const values: Array<number | null> = [];
        for (let i = 0; i < len; i++) {
          const hasValue = d.readBool();
          if (hasValue) {
            values.push(d.readU8());
          } else {
            values.push(null);
          }
        }
        d.checkEnd();
        const s = new BcsSerializer();
        s.writeUleb128(values.length);
        for (const v of values) {
          if (v !== null) {
            s.writeBool(true);
            s.writeU8(v);
          } else {
            s.writeBool(false);
          }
        }
        resultHex = bytesToHex(s.toBytes());
      } else {
        return {
          name,
          type: typ,
          bcs_hex: "",
          value: testCase.value,
          error: `Unknown type: ${typ}`,
        };
      }

      return {
        name,
        type: typ,
        bcs_hex: resultHex,
        value: testCase.value,
      };
    } catch (e: any) {
      return {
        name,
        type: typ,
        bcs_hex: "",
        value: testCase.value,
        error: e.message || String(e),
      };
    }
  }

  // Process each category
  const output: TestVectors = {
    version: vectors.version || "1.0.0",
    description: "TypeScript roundtrip results",
    primitives: vectors.primitives?.map(processTestCase) || [],
    strings: vectors.strings?.map(processTestCase) || [],
    bytes: vectors.bytes?.map(processTestCase) || [],
    options: vectors.options?.map(processTestCase) || [],
    vectors: vectors.vectors?.map(processTestCase) || [],
    structs: vectors.structs?.map(processTestCase) || [],
    complex: vectors.complex?.map(processTestCase) || [],
  };

  console.log(JSON.stringify(output, null, 2));
}

// Benchmark types and functions
interface BenchmarkSpec {
  version: string;
  config: {
    default_iterations: number;
    warmup_iterations: number;
  };
  scenarios: Record<string, { benchmarks: BenchmarkCase[] }>;
}

interface BenchmarkCase {
  name: string;
  type: string;
  value?: any;
  value_generator?: string;
  length?: number;
  char?: string;
  iterations?: number;
}

interface BenchmarkResult {
  name: string;
  type: string;
  iterations: number;
  serialize_avg_ns: number;
  serialize_min_ns: number;
  serialize_max_ns: number;
  serialize_p50_ns: number;
  serialize_p95_ns: number;
  deserialize_avg_ns: number;
  deserialize_min_ns: number;
  deserialize_max_ns: number;
  deserialize_p50_ns: number;
  deserialize_p95_ns: number;
  throughput_serialize_ops_sec: number;
  throughput_deserialize_ops_sec: number;
  error?: string;
}

function computeStats(times: number[]): {
  avg: number;
  min: number;
  max: number;
  p50: number;
  p95: number;
} {
  if (times.length === 0) return { avg: 0, min: 0, max: 0, p50: 0, p95: 0 };
  const sorted = [...times].sort((a, b) => a - b);
  const n = sorted.length;
  return {
    avg: times.reduce((a, b) => a + b, 0) / n,
    min: sorted[0],
    max: sorted[n - 1],
    p50: sorted[Math.floor(n / 2)],
    p95: sorted[Math.floor(n * 0.95)],
  };
}

function generateValue(bc: BenchmarkCase): any {
  if (bc.value !== undefined) return bc.value;
  const length = bc.length ?? 10;
  switch (bc.value_generator) {
    case "repeat_char":
      return (bc.char ?? "a").repeat(length);
    case "sequential_bytes":
    case "sequential_u8":
      return Array.from({ length }, (_, i) => i % 256);
    case "sequential_u64":
      return Array.from({ length }, (_, i) => i.toString());
    case "address_bytes":
      return [...Array(31).fill(0), 1];
    default:
      return bc.value;
  }
}

async function runBenchmarks(spec: BenchmarkSpec) {
  const { BcsSerializer, BcsDeserializer } = await loadBcs();
  const results: BenchmarkResult[] = [];
  const defaultIterations = spec.config.default_iterations ?? 1000;
  const warmup = spec.config.warmup_iterations ?? 10;

  for (const [, group] of Object.entries(spec.scenarios)) {
    for (const bc of group.benchmarks) {
      const iterations = bc.iterations ?? defaultIterations;
      const value = generateValue(bc);

      try {
        // Serialize to get bytes
        const serializeOnce = () => {
          const s = new BcsSerializer();
          serializeValue(s, bc.type, value);
          return s.toBytes();
        };

        const bcsBytes = serializeOnce();

        // Warmup serialize
        for (let i = 0; i < warmup; i++) serializeOnce();

        // Benchmark serialize
        const serTimes: number[] = [];
        for (let i = 0; i < iterations; i++) {
          const start = performance.now();
          serializeOnce();
          serTimes.push((performance.now() - start) * 1_000_000); // ms to ns
        }

        // Warmup deserialize
        for (let i = 0; i < warmup; i++) {
          const d = new BcsDeserializer(bcsBytes);
          deserializeValue(d, bc.type);
        }

        // Benchmark deserialize
        const deTimes: number[] = [];
        for (let i = 0; i < iterations; i++) {
          const start = performance.now();
          const d = new BcsDeserializer(bcsBytes);
          deserializeValue(d, bc.type);
          deTimes.push((performance.now() - start) * 1_000_000);
        }

        const serStats = computeStats(serTimes);
        const deStats = computeStats(deTimes);

        results.push({
          name: bc.name,
          type: bc.type,
          iterations,
          serialize_avg_ns: serStats.avg,
          serialize_min_ns: serStats.min,
          serialize_max_ns: serStats.max,
          serialize_p50_ns: serStats.p50,
          serialize_p95_ns: serStats.p95,
          deserialize_avg_ns: deStats.avg,
          deserialize_min_ns: deStats.min,
          deserialize_max_ns: deStats.max,
          deserialize_p50_ns: deStats.p50,
          deserialize_p95_ns: deStats.p95,
          throughput_serialize_ops_sec:
            serStats.avg > 0 ? 1_000_000_000 / serStats.avg : 0,
          throughput_deserialize_ops_sec:
            deStats.avg > 0 ? 1_000_000_000 / deStats.avg : 0,
        });
      } catch (e: any) {
        results.push({
          name: bc.name,
          type: bc.type,
          iterations,
          serialize_avg_ns: 0,
          serialize_min_ns: 0,
          serialize_max_ns: 0,
          serialize_p50_ns: 0,
          serialize_p95_ns: 0,
          deserialize_avg_ns: 0,
          deserialize_min_ns: 0,
          deserialize_max_ns: 0,
          deserialize_p50_ns: 0,
          deserialize_p95_ns: 0,
          throughput_serialize_ops_sec: 0,
          throughput_deserialize_ops_sec: 0,
          error: e.message || String(e),
        });
      }
    }
  }

  return {
    version: spec.version,
    description: "TypeScript benchmark results",
    benchmarks: results,
  };
}

function serializeValue(s: any, typ: string, value: any): void {
  switch (typ) {
    case "bool":
      s.writeBool(value);
      break;
    case "u8":
      s.writeU8(value);
      break;
    case "u16":
      s.writeU16(value);
      break;
    case "u32":
      s.writeU32(value);
      break;
    case "u64":
      s.writeU64(BigInt(value));
      break;
    case "u128":
      s.writeU128(BigInt(value));
      break;
    case "i8":
      s.writeI8(value);
      break;
    case "i16":
      s.writeI16(value);
      break;
    case "i32":
      s.writeI32(value);
      break;
    case "i64":
      s.writeI64(BigInt(value));
      break;
    case "i128":
      s.writeI128(BigInt(value));
      break;
    case "string":
      s.writeString(value);
      break;
    case "bytes":
      s.writeBytes(new Uint8Array(value));
      break;
    case "fixed_bytes":
      s.writeFixedBytes(new Uint8Array(value), value.length);
      break;
    case "vector<u8>":
      s.writeUleb128(value.length);
      for (const v of value) s.writeU8(v);
      break;
    case "vector<u64>":
      s.writeUleb128(value.length);
      for (const v of value) s.writeU64(BigInt(v));
      break;
    case "vector<string>":
      s.writeUleb128(value.length);
      for (const v of value) s.writeString(v);
      break;
    default:
      throw new Error(`Unknown type for benchmark: ${typ}`);
  }
}

function deserializeValue(d: any, typ: string): any {
  switch (typ) {
    case "bool":
      return d.readBool();
    case "u8":
      return d.readU8();
    case "u16":
      return d.readU16();
    case "u32":
      return d.readU32();
    case "u64":
      return d.readU64();
    case "u128":
      return d.readU128();
    case "i8":
      return d.readI8();
    case "i16":
      return d.readI16();
    case "i32":
      return d.readI32();
    case "i64":
      return d.readI64();
    case "i128":
      return d.readI128();
    case "string":
      return d.readString();
    case "bytes":
      return d.readBytes();
    case "fixed_bytes":
      return d.readFixedBytes(32);
    case "vector<u8>": {
      const len = d.readUleb128();
      return Array.from({ length: len }, () => d.readU8());
    }
    case "vector<u64>": {
      const len = d.readUleb128();
      return Array.from({ length: len }, () => d.readU64());
    }
    case "vector<string>": {
      const len = d.readUleb128();
      return Array.from({ length: len }, () => d.readString());
    }
    default:
      throw new Error(`Unknown type for benchmark: ${typ}`);
  }
}

async function mainWithBenchmark() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false,
  });

  let inputData = "";
  for await (const line of rl) {
    inputData += line;
  }

  const spec: BenchmarkSpec = JSON.parse(inputData);
  const output = await runBenchmarks(spec);
  console.log(JSON.stringify(output, null, 2));
}

if (benchmarkMode) {
  mainWithBenchmark().catch((e) => {
    console.error(e);
    process.exit(1);
  });
} else {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
