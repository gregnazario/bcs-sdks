# BCS SDK Benchmark Report

**Generated**: 2026-01-27 09:23:18
**Commit**: 6eb1847

## Test Environment

- **Platform**: Darwin 25.2.0
- **Architecture**: arm64
- **Processor**: arm
- **CPU Cores**: 16
- **Python Version**: 3.14.2

## Summary

- **Languages Tested**: 14
- **Total Correctness Tests**: 1036
- **Tests Passed**: 1036
- **Tests Failed**: 0
- **Benchmark Scenarios**: 35

## Performance Comparison

| Language | Correctness | Serialize | Deserialize | vs Rust (Ser) | vs Rust (De) |
|----------|-------------|-----------|-------------|---------------|--------------|
| rust     | 74/74 PASS  | 107 ns    | 108 ns      | baseline      | baseline     |
| go       | 74/74 PASS  | 540 ns    | 190 ns      | 5.1x          | 1.8x         |
| typescript | 74/74 PASS  | 6.03 us   | 8.08 us     | 56.5x         | 74.6x        |
| python   | 74/74 PASS  | 7.27 us   | 5.09 us     | 68.2x         | 47.0x        |
| ruby     | 74/74 PASS  | 20.67 us  | 26.01 us    | 193.8x        | 240.2x       |
| elixir   | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| cpp      | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| csharp   | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| kotlin   | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| swift    | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| c        | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| zig      | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| dart     | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |
| java     | 74/74 PASS  | 0 ns      | 0 ns        | N/A           | N/A          |

## Performance Charts

### Serialization Performance (lower is better)

```
rust         |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 107 ns
go           |█░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 540 ns
typescript   |███████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 6.03 us
python       |██████████████░░░░░░░░░░░░░░░░░░░░░░░░░░| 7.27 us
ruby         |████████████████████████████████████████| 20.67 us
```

### Deserialization Performance (lower is better)

```
rust         |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 108 ns
go           |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 190 ns
python       |███████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 5.09 us
typescript   |████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 8.08 us
ruby         |████████████████████████████████████████| 26.01 us
```

## Detailed Benchmark Results

### u8

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 160 ns          | 40 ns             | 6.25M ops/s    | 25.16M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 318 ns          | 328 ns            | 3.14M ops/s    | 3.05M ops/s   |
| ruby     | 1.63 us         | 295 ns            | 615.01K ops/s  | 3.39M ops/s   |
| rust     | 23 ns           | 24 ns             | 42.62M ops/s   | 42.41M ops/s  |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 650 ns          | 213 ns            | 1.54M ops/s    | 4.70M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### u16

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 159 ns          | 48 ns             | 6.29M ops/s    | 20.96M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 365 ns          | 434 ns            | 2.74M ops/s    | 2.31M ops/s   |
| ruby     | 1.01 us         | 338 ns            | 986.19K ops/s  | 2.96M ops/s   |
| rust     | 24 ns           | 23 ns             | 41.87M ops/s   | 42.92M ops/s  |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 10.36 us        | 343 ns            | 96.51K ops/s   | 2.92M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### u32

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 156 ns          | 35 ns             | 6.40M ops/s    | 28.20M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 400 ns          | 1.15 us           | 2.50M ops/s    | 870.79K ops/s |
| ruby     | 838 ns          | 555 ns            | 1.19M ops/s    | 1.80M ops/s   |
| rust     | 23 ns           | 24 ns             | 42.88M ops/s   | 42.34M ops/s  |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 476 ns          | 195 ns            | 2.10M ops/s    | 5.13M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### u64

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 434 ns          | 54 ns             | 2.31M ops/s    | 18.63M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 455 ns          | 425 ns            | 2.20M ops/s    | 2.35M ops/s   |
| ruby     | 602 ns          | 354 ns            | 1.66M ops/s    | 2.82M ops/s   |
| rust     | Error: invalid type: string "18446744              |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 2.06 us         | 451 ns            | 485.13K ops/s  | 2.22M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### u128

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 838 ns          | 84 ns             | 1.19M ops/s    | 11.89M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 478 ns          | 489 ns            | 2.09M ops/s    | 2.04M ops/s   |
| ruby     | 1.23 us         | 1.58 us           | 816.33K ops/s  | 632.11K ops/s |
| rust     | Error: invalid type: string "34028236              |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 2.26 us         | 2.88 us           | 443.02K ops/s  | 346.67K ops/s |
| zig      | N/A | N/A | N/A | N/A |

### i8

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 87 ns           | 23 ns             | 11.43M ops/s   | 43.98M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 336 ns          | 438 ns            | 2.98M ops/s    | 2.28M ops/s   |
| ruby     | 444 ns          | 345 ns            | 2.25M ops/s    | 2.90M ops/s   |
| rust     | 24 ns           | 24 ns             | 42.30M ops/s   | 41.80M ops/s  |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 887 ns          | 110 ns            | 1.13M ops/s    | 9.10M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### i16

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 97 ns           | 23 ns             | 10.29M ops/s   | 43.65M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 407 ns          | 442 ns            | 2.45M ops/s    | 2.26M ops/s   |
| ruby     | 656 ns          | 375 ns            | 1.52M ops/s    | 2.67M ops/s   |
| rust     | 23 ns           | 23 ns             | 42.77M ops/s   | 43.47M ops/s  |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 379 ns          | 140 ns            | 2.64M ops/s    | 7.12M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### i32

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 79 ns           | 24 ns             | 12.66M ops/s   | 42.31M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 429 ns          | 543 ns            | 2.33M ops/s    | 1.84M ops/s   |
| ruby     | 458 ns          | 341 ns            | 2.18M ops/s    | 2.93M ops/s   |
| rust     | 23 ns           | 24 ns             | 43.17M ops/s   | 42.25M ops/s  |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 409 ns          | 119 ns            | 2.45M ops/s    | 8.39M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### i64

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 655 ns          | 26 ns             | 1.53M ops/s    | 39.14M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 1.51 us         | 988 ns            | 661.89K ops/s  | 1.01M ops/s   |
| ruby     | 785 ns          | 447 ns            | 1.27M ops/s    | 2.24M ops/s   |
| rust     | Error: invalid type: string "-9223372              |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 935 ns          | 348 ns            | 1.07M ops/s    | 2.87M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

### i128

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | N/A | N/A | N/A | N/A |
| cpp      | N/A | N/A | N/A | N/A |
| csharp   | N/A | N/A | N/A | N/A |
| dart     | N/A | N/A | N/A | N/A |
| elixir   | N/A | N/A | N/A | N/A |
| go       | 477 ns          | 92 ns             | 2.10M ops/s    | 10.88M ops/s  |
| java     | N/A | N/A | N/A | N/A |
| kotlin   | N/A | N/A | N/A | N/A |
| python   | 670 ns          | 536 ns            | 1.49M ops/s    | 1.87M ops/s   |
| ruby     | 1.04 us         | 703 ns            | 960.61K ops/s  | 1.42M ops/s   |
| rust     | Error: invalid type: string "-1701411              |
| swift    | N/A | N/A | N/A | N/A |
| typescript | 991 ns          | 637 ns            | 1.01M ops/s    | 1.57M ops/s   |
| zig      | N/A | N/A | N/A | N/A |

## Correctness Test Details

### Python - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Typescript - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Go - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Elixir - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Rust - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Cpp - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Csharp - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Kotlin - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Swift - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Ruby - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### C - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Zig - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Dart - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

### Java - PASS

- Passed: 74
- Failed: 0
- Skipped: 0

---

*Report generated by BCS Benchmark Orchestrator*