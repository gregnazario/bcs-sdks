// Rust BCS E2E Test Runner
//
// Supports two modes:
// - Default: Roundtrip testing for correctness
// - Benchmark (--benchmark): Performance timing

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::env;
use std::io::{self, Read, Write};
use std::time::Instant;

fn hex_to_bytes(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap_or(0))
        .collect()
}

fn bytes_to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

fn do_roundtrip<T: serde::de::DeserializeOwned + serde::Serialize>(data: &[u8]) -> Result<String, String> {
    let v: T = bcs::from_bytes(data).map_err(|e| e.to_string())?;
    let out = bcs::to_bytes(&v).map_err(|e| e.to_string())?;
    Ok(bytes_to_hex(&out))
}

fn process_test_case(name: &str, type_name: &str, bcs_hex: &str, value: &Value) -> Value {
    let data = hex_to_bytes(bcs_hex);
    
    let result: Result<String, String> = match type_name {
        "bool" => do_roundtrip::<bool>(&data),
        "u8" => do_roundtrip::<u8>(&data),
        "u16" => do_roundtrip::<u16>(&data),
        "u32" => do_roundtrip::<u32>(&data),
        "u64" => do_roundtrip::<u64>(&data),
        "u128" => do_roundtrip::<u128>(&data),
        "i8" => do_roundtrip::<i8>(&data),
        "i16" => do_roundtrip::<i16>(&data),
        "i32" => do_roundtrip::<i32>(&data),
        "i64" => do_roundtrip::<i64>(&data),
        "i128" => do_roundtrip::<i128>(&data),
        "string" => do_roundtrip::<String>(&data),
        "bytes" => do_roundtrip::<Vec<u8>>(&data),
        "fixed_bytes_32" => do_roundtrip::<[u8; 32]>(&data),
        "option<u8>" => do_roundtrip::<Option<u8>>(&data),
        "option<u64>" => do_roundtrip::<Option<u64>>(&data),
        "option<bool>" => do_roundtrip::<Option<bool>>(&data),
        "option<string>" => do_roundtrip::<Option<String>>(&data),
        "vector<u8>" => do_roundtrip::<Vec<u8>>(&data),
        "vector<u64>" => do_roundtrip::<Vec<u64>>(&data),
        "vector<bool>" => do_roundtrip::<Vec<bool>>(&data),
        "vector<string>" => do_roundtrip::<Vec<String>>(&data),
        "vector<vector<u8>>" => do_roundtrip::<Vec<Vec<u8>>>(&data),
        "vector<option<u8>>" => do_roundtrip::<Vec<Option<u8>>>(&data),
        "map<u8,u8>" => do_roundtrip::<BTreeMap<u8, u8>>(&data),
        "map<string,u64>" => do_roundtrip::<BTreeMap<String, u64>>(&data),
        "tuple<u8,u64>" => do_roundtrip::<(u8, u64)>(&data),
        "struct" => {
            // Handle struct based on fields
            if let Some(fields) = value.get("fields").and_then(|f| f.as_array()) {
                process_struct(&data, fields)
            } else {
                Err("Invalid struct value".to_string())
            }
        }
        _ => Err(format!("Unknown type: {}", type_name)),
    };

    match result {
        Ok(hex) => json!({
            "name": name,
            "type": type_name,
            "bcs_hex": hex,
            "value": value
        }),
        Err(e) => json!({
            "name": name,
            "type": type_name,
            "bcs_hex": "",
            "value": value,
            "error": e
        }),
    }
}

fn process_struct(data: &[u8], fields: &[Value]) -> Result<String, String> {
    // For structs, we need to handle them dynamically
    // Since Rust's serde requires compile-time types, we'll manually deserialize
    let mut offset = 0;
    let mut serializer = Vec::new();

    for field in fields {
        let field_type = field.get("type").and_then(|t| t.as_str()).unwrap_or("");
        
        match field_type {
            "u8" => {
                if offset >= data.len() { return Err("Unexpected EOF".to_string()); }
                let v = data[offset];
                offset += 1;
                serializer.push(v);
            }
            "u64" => {
                if offset + 8 > data.len() { return Err("Unexpected EOF".to_string()); }
                serializer.extend_from_slice(&data[offset..offset + 8]);
                offset += 8;
            }
            "string" => {
                // Read ULEB128 length
                let (len, bytes_read) = read_uleb128(&data[offset..])?;
                serializer.extend_from_slice(&data[offset..offset + bytes_read]);
                offset += bytes_read;
                
                if offset + len > data.len() { return Err("Unexpected EOF".to_string()); }
                serializer.extend_from_slice(&data[offset..offset + len]);
                offset += len;
            }
            "fixed_bytes_32" => {
                if offset + 32 > data.len() { return Err("Unexpected EOF".to_string()); }
                serializer.extend_from_slice(&data[offset..offset + 32]);
                offset += 32;
            }
            _ => return Err(format!("Unknown field type: {}", field_type)),
        }
    }

    if offset != data.len() {
        return Err("Remaining input".to_string());
    }

    Ok(bytes_to_hex(&serializer))
}

fn read_uleb128(data: &[u8]) -> Result<(usize, usize), String> {
    let mut value = 0usize;
    let mut shift = 0;
    let mut offset = 0;

    loop {
        if offset >= data.len() {
            return Err("Unexpected EOF in ULEB128".to_string());
        }
        let byte = data[offset];
        offset += 1;
        value |= ((byte & 0x7F) as usize) << shift;
        if byte & 0x80 == 0 {
            break;
        }
        shift += 7;
    }

    Ok((value, offset))
}

fn process_category(tests: &Value) -> Vec<Value> {
    tests
        .as_array()
        .map(|arr| {
            arr.iter()
                .map(|test| {
                    let name = test.get("name").and_then(|n| n.as_str()).unwrap_or("");
                    let type_name = test.get("type").and_then(|t| t.as_str()).unwrap_or("");
                    let bcs_hex = test.get("bcs_hex").and_then(|h| h.as_str()).unwrap_or("");
                    let value = test.get("value").cloned().unwrap_or(Value::Null);
                    process_test_case(name, type_name, bcs_hex, &value)
                })
                .collect()
        })
        .unwrap_or_default()
}

// Benchmark types
#[derive(Debug, Deserialize)]
struct BenchmarkSpec {
    version: String,
    config: BenchmarkConfig,
    scenarios: BTreeMap<String, BenchmarkGroup>,
}

#[derive(Debug, Deserialize)]
struct BenchmarkConfig {
    default_iterations: Option<usize>,
    warmup_iterations: Option<usize>,
}

#[derive(Debug, Deserialize)]
struct BenchmarkGroup {
    benchmarks: Vec<BenchmarkCase>,
}

#[derive(Debug, Deserialize)]
struct BenchmarkCase {
    name: String,
    #[serde(rename = "type")]
    type_name: String,
    value: Option<Value>,
    value_generator: Option<String>,
    length: Option<usize>,
    char: Option<String>,
    iterations: Option<usize>,
}

#[derive(Debug, Serialize)]
struct BenchmarkResult {
    name: String,
    #[serde(rename = "type")]
    type_name: String,
    iterations: usize,
    serialize_avg_ns: f64,
    serialize_min_ns: f64,
    serialize_max_ns: f64,
    serialize_p50_ns: f64,
    serialize_p95_ns: f64,
    deserialize_avg_ns: f64,
    deserialize_min_ns: f64,
    deserialize_max_ns: f64,
    deserialize_p50_ns: f64,
    deserialize_p95_ns: f64,
    throughput_serialize_ops_sec: f64,
    throughput_deserialize_ops_sec: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Serialize)]
struct BenchmarkOutput {
    version: String,
    description: String,
    benchmarks: Vec<BenchmarkResult>,
}

fn compute_stats(times: &mut [u64]) -> (f64, f64, f64, f64, f64) {
    if times.is_empty() {
        return (0.0, 0.0, 0.0, 0.0, 0.0);
    }

    times.sort();
    let n = times.len();
    let sum: u64 = times.iter().sum();

    let avg = sum as f64 / n as f64;
    let min = times[0] as f64;
    let max = times[n - 1] as f64;
    let p50 = times[n / 2] as f64;
    let p95_idx = (n as f64 * 0.95) as usize;
    let p95 = times[p95_idx.min(n - 1)] as f64;

    (avg, min, max, p50, p95)
}

fn generate_value(case: &BenchmarkCase) -> Option<Value> {
    if let Some(ref val) = case.value {
        return Some(val.clone());
    }

    let length = case.length.unwrap_or(10);

    match case.value_generator.as_deref() {
        Some("repeat_char") => {
            let c = case.char.as_deref().unwrap_or("a");
            Some(json!(c.repeat(length)))
        }
        Some("sequential_bytes") | Some("sequential_u8") => {
            let bytes: Vec<u8> = (0..length).map(|i| (i % 256) as u8).collect();
            Some(json!(bytes))
        }
        Some("sequential_u64") => {
            let values: Vec<String> = (0..length).map(|i| i.to_string()).collect();
            Some(json!(values))
        }
        Some("address_bytes") => {
            let mut bytes = vec![0u8; 31];
            bytes.push(1);
            Some(json!(bytes))
        }
        _ => case.value.clone(),
    }
}

macro_rules! benchmark_type {
    ($type:ty, $value:expr, $iterations:expr, $warmup:expr) => {{
        let v: $type = serde_json::from_value($value.clone()).map_err(|e| e.to_string())?;
        
        // Get serialized bytes for deserialize benchmark
        let bcs_bytes = bcs::to_bytes(&v).map_err(|e| e.to_string())?;
        
        // Warmup serialize
        for _ in 0..$warmup {
            let _ = bcs::to_bytes(&v);
        }
        
        // Benchmark serialize
        let mut ser_times = Vec::with_capacity($iterations);
        for _ in 0..$iterations {
            let start = Instant::now();
            let _ = bcs::to_bytes(&v);
            ser_times.push(start.elapsed().as_nanos() as u64);
        }
        
        // Warmup deserialize
        for _ in 0..$warmup {
            let _: $type = bcs::from_bytes(&bcs_bytes).unwrap();
        }
        
        // Benchmark deserialize
        let mut de_times = Vec::with_capacity($iterations);
        for _ in 0..$iterations {
            let start = Instant::now();
            let _: $type = bcs::from_bytes(&bcs_bytes).unwrap();
            de_times.push(start.elapsed().as_nanos() as u64);
        }
        
        Ok((ser_times, de_times))
    }};
}

fn run_benchmark_case(
    case: &BenchmarkCase,
    iterations: usize,
    warmup: usize,
) -> Result<(Vec<u64>, Vec<u64>), String> {
    let value = generate_value(case).ok_or("Could not generate value")?;

    match case.type_name.as_str() {
        "bool" => benchmark_type!(bool, value, iterations, warmup),
        "u8" => benchmark_type!(u8, value, iterations, warmup),
        "u16" => benchmark_type!(u16, value, iterations, warmup),
        "u32" => benchmark_type!(u32, value, iterations, warmup),
        "u64" => benchmark_type!(u64, value, iterations, warmup),
        "u128" => benchmark_type!(u128, value, iterations, warmup),
        "i8" => benchmark_type!(i8, value, iterations, warmup),
        "i16" => benchmark_type!(i16, value, iterations, warmup),
        "i32" => benchmark_type!(i32, value, iterations, warmup),
        "i64" => benchmark_type!(i64, value, iterations, warmup),
        "i128" => benchmark_type!(i128, value, iterations, warmup),
        "string" => benchmark_type!(String, value, iterations, warmup),
        "bytes" => benchmark_type!(Vec<u8>, value, iterations, warmup),
        "fixed_bytes" => benchmark_type!([u8; 32], value, iterations, warmup),
        "vector<u8>" => benchmark_type!(Vec<u8>, value, iterations, warmup),
        "vector<u64>" => benchmark_type!(Vec<u64>, value, iterations, warmup),
        "vector<string>" => benchmark_type!(Vec<String>, value, iterations, warmup),
        _ => Err(format!("Unknown type for benchmark: {}", case.type_name)),
    }
}

fn run_benchmarks(spec: BenchmarkSpec) -> BenchmarkOutput {
    let default_iterations = spec.config.default_iterations.unwrap_or(1000);
    let warmup = spec.config.warmup_iterations.unwrap_or(10);

    let mut results = Vec::new();

    for (_category, group) in &spec.scenarios {
        for case in &group.benchmarks {
            let iterations = case.iterations.unwrap_or(default_iterations);

            match run_benchmark_case(case, iterations, warmup) {
                Ok((mut ser_times, mut de_times)) => {
                    let (ser_avg, ser_min, ser_max, ser_p50, ser_p95) = compute_stats(&mut ser_times);
                    let (de_avg, de_min, de_max, de_p50, de_p95) = compute_stats(&mut de_times);

                    let ser_throughput = if ser_avg > 0.0 { 1_000_000_000.0 / ser_avg } else { 0.0 };
                    let de_throughput = if de_avg > 0.0 { 1_000_000_000.0 / de_avg } else { 0.0 };

                    results.push(BenchmarkResult {
                        name: case.name.clone(),
                        type_name: case.type_name.clone(),
                        iterations,
                        serialize_avg_ns: ser_avg,
                        serialize_min_ns: ser_min,
                        serialize_max_ns: ser_max,
                        serialize_p50_ns: ser_p50,
                        serialize_p95_ns: ser_p95,
                        deserialize_avg_ns: de_avg,
                        deserialize_min_ns: de_min,
                        deserialize_max_ns: de_max,
                        deserialize_p50_ns: de_p50,
                        deserialize_p95_ns: de_p95,
                        throughput_serialize_ops_sec: ser_throughput,
                        throughput_deserialize_ops_sec: de_throughput,
                        error: None,
                    });
                }
                Err(e) => {
                    results.push(BenchmarkResult {
                        name: case.name.clone(),
                        type_name: case.type_name.clone(),
                        iterations,
                        serialize_avg_ns: 0.0,
                        serialize_min_ns: 0.0,
                        serialize_max_ns: 0.0,
                        serialize_p50_ns: 0.0,
                        serialize_p95_ns: 0.0,
                        deserialize_avg_ns: 0.0,
                        deserialize_min_ns: 0.0,
                        deserialize_max_ns: 0.0,
                        deserialize_p50_ns: 0.0,
                        deserialize_p95_ns: 0.0,
                        throughput_serialize_ops_sec: 0.0,
                        throughput_deserialize_ops_sec: 0.0,
                        error: Some(e),
                    });
                }
            }
        }
    }

    BenchmarkOutput {
        version: spec.version,
        description: "Rust benchmark results".to_string(),
        benchmarks: results,
    }
}

fn run_roundtrip() -> io::Result<()> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;

    let vectors: Value = serde_json::from_str(&input).unwrap_or(json!({}));

    let output = json!({
        "version": "1.0.0",
        "description": "Rust roundtrip results",
        "primitives": process_category(vectors.get("primitives").unwrap_or(&Value::Null)),
        "strings": process_category(vectors.get("strings").unwrap_or(&Value::Null)),
        "bytes": process_category(vectors.get("bytes").unwrap_or(&Value::Null)),
        "options": process_category(vectors.get("options").unwrap_or(&Value::Null)),
        "vectors": process_category(vectors.get("vectors").unwrap_or(&Value::Null)),
        "structs": process_category(vectors.get("structs").unwrap_or(&Value::Null)),
        "complex": process_category(vectors.get("complex").unwrap_or(&Value::Null)),
    });

    io::stdout().write_all(serde_json::to_string_pretty(&output)?.as_bytes())?;
    io::stdout().write_all(b"\n")?;

    Ok(())
}

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let benchmark_mode = args.iter().any(|a| a == "--benchmark");

    if benchmark_mode {
        let mut input = String::new();
        io::stdin().read_to_string(&mut input)?;

        let spec: BenchmarkSpec = serde_json::from_str(&input)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

        let output = run_benchmarks(spec);

        io::stdout().write_all(serde_json::to_string_pretty(&output)?.as_bytes())?;
        io::stdout().write_all(b"\n")?;
    } else {
        run_roundtrip()?;
    }

    Ok(())
}
