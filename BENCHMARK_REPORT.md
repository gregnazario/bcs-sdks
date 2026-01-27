# BCS SDK Benchmark Report

**Generated**: 2026-01-27 11:25:02
**Commit**: baabf38

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
| rust     | 74/74 PASS  | 62 ns     | 77 ns       | baseline      | baseline     |
| cpp      | 74/74 PASS  | 77 ns     | 28 ns       | 1.2x          | 0.4x         |
| c        | 74/74 PASS  | 73 ns     | 29 ns       | 4.5x          | 1.9x         |
| go       | 74/74 PASS  | 636 ns    | 174 ns      | 10.2x         | 2.3x         |
| csharp   | 74/74 PASS  | 1.79 us   | 3.11 us     | 28.8x         | 40.6x        |
| kotlin   | 74/74 PASS  | 4.05 us   | 1.30 us     | 65.1x         | 17.0x        |
| python   | 74/74 PASS  | 4.96 us   | 8.16 us     | 79.8x         | 106.4x       |
| typescript | 74/74 PASS  | 6.00 us   | 4.22 us     | 96.4x         | 55.0x        |
| java     | 74/74 PASS  | 6.07 us   | 412 ns      | 97.7x         | 5.4x         |
| elixir   | 74/74 PASS  | 6.57 us   | 174.74 us   | 105.7x        | 2280.5x      |
| dart     | 74/74 PASS  | 6.86 us   | 6.92 us     | 110.2x        | 90.4x        |
| ruby     | 74/74 PASS  | 25.91 us  | 26.11 us    | 416.6x        | 340.7x       |
| swift    | 74/74 PASS  | 52.51 us  | 68.15 us    | 844.2x        | 889.4x       |
| zig      | 74/74 PASS  | 31.18 us  | 7.83 us     | 1489.6x       | 424.0x       |

## Performance Charts

### Serialization Performance (lower is better)

```
rust         |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 62 ns
c            |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 73 ns
cpp          |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 77 ns
go           |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 636 ns
csharp       |█░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 1.79 us
kotlin       |███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 4.05 us
python       |███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 4.96 us
typescript   |████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 6.00 us
java         |████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 6.07 us
elixir       |█████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 6.57 us
dart         |█████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 6.86 us
ruby         |███████████████████░░░░░░░░░░░░░░░░░░░░░| 25.91 us
zig          |███████████████████████░░░░░░░░░░░░░░░░░| 31.18 us
swift        |████████████████████████████████████████| 52.51 us
```

### Deserialization Performance (lower is better)

```
cpp          |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 28 ns
c            |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 29 ns
rust         |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 77 ns
go           |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 174 ns
java         |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 412 ns
kotlin       |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 1.30 us
csharp       |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 3.11 us
typescript   |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 4.22 us
dart         |█░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 6.92 us
zig          |█░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 7.83 us
python       |█░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 8.16 us
ruby         |█████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░| 26.11 us
swift        |███████████████░░░░░░░░░░░░░░░░░░░░░░░░░| 68.15 us
elixir       |████████████████████████████████████████| 174.74 us
```

## Detailed Benchmark Results

### u8

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 91 ns           | 31 ns             | 10.99M ops/s   | 32.26M ops/s  |
| cpp      | 36 ns           | 21 ns             | 27.59M ops/s   | 48.10M ops/s  |
| csharp   | 65 ns           | 34 ns             | 15.36M ops/s   | 29.56M ops/s  |
| dart     | 131 ns          | 4 ns              | 7.63M ops/s    | 250.00M ops/s |
| elixir   | 237 ns          | 63 ns             | 4.22M ops/s    | 15.87M ops/s  |
| go       | 63 ns           | 21 ns             | 15.99M ops/s   | 47.81M ops/s  |
| java     | 760 ns          | 233 ns            | 1.32M ops/s    | 4.29M ops/s   |
| kotlin   | 1.29 us         | 275 ns            | 0 ops/s        | 0 ops/s       |
| python   | 345 ns          | 374 ns            | 2.90M ops/s    | 2.67M ops/s   |
| ruby     | 4.17 us         | 347 ns            | 239.87K ops/s  | 2.88M ops/s   |
| rust     | 21 ns           | 21 ns             | 48.00M ops/s   | 46.88M ops/s  |
| swift    | 209 ns          | 124 ns            | 4.77M ops/s    | 8.04M ops/s   |
| typescript | 710 ns          | 382 ns            | 1.41M ops/s    | 2.62M ops/s   |
| zig      | 11.54 us        | 40 ns             | 86.66K ops/s   | 25.00M ops/s  |

### u16

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 54 ns           | 26 ns             | 18.52M ops/s   | 38.46M ops/s  |
| cpp      | 67 ns           | 19 ns             | 14.94M ops/s   | 52.28M ops/s  |
| csharp   | 61 ns           | 52 ns             | 16.45M ops/s   | 19.12M ops/s  |
| dart     | 360 ns          | 1 ns              | 2.78M ops/s    | 1000.00M ops/s |
| elixir   | 126 ns          | 57 ns             | 7.93M ops/s    | 17.62M ops/s  |
| go       | 60 ns           | 23 ns             | 16.75M ops/s   | 44.02M ops/s  |
| java     | 509 ns          | 225 ns            | 1.96M ops/s    | 4.44M ops/s   |
| kotlin   | 844 ns          | 135 ns            | 0 ops/s        | 0 ops/s       |
| python   | 408 ns          | 479 ns            | 2.45M ops/s    | 2.09M ops/s   |
| ruby     | 2.96 us         | 405 ns            | 338.18K ops/s  | 2.47M ops/s   |
| rust     | 21 ns           | 21 ns             | 46.98M ops/s   | 46.69M ops/s  |
| swift    | 237 ns          | 158 ns            | 4.22M ops/s    | 6.34M ops/s   |
| typescript | 545 ns          | 490 ns            | 1.83M ops/s    | 2.04M ops/s   |
| zig      | 12.15 us        | 34 ns             | 82.28K ops/s   | 29.41M ops/s  |

### u32

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 56 ns           | 22 ns             | 17.86M ops/s   | 45.45M ops/s  |
| cpp      | 105 ns          | 21 ns             | 9.56M ops/s    | 48.49M ops/s  |
| csharp   | 79 ns           | 38 ns             | 12.73M ops/s   | 25.99M ops/s  |
| dart     | 1.36 us         | 60 ns             | 733.14K ops/s  | 16.67M ops/s  |
| elixir   | 122 ns          | 58 ns             | 8.18M ops/s    | 17.17M ops/s  |
| go       | 60 ns           | 23 ns             | 16.70M ops/s   | 42.96M ops/s  |
| java     | 359 ns          | 188 ns            | 2.78M ops/s    | 5.32M ops/s   |
| kotlin   | 653 ns          | 141 ns            | 0 ops/s        | 0 ops/s       |
| python   | 449 ns          | 504 ns            | 2.23M ops/s    | 1.98M ops/s   |
| ruby     | 1.04 us         | 709 ns            | 961.54K ops/s  | 1.41M ops/s   |
| rust     | 22 ns           | 21 ns             | 45.97M ops/s   | 46.60M ops/s  |
| swift    | 808 ns          | 752 ns            | 1.24M ops/s    | 1.33M ops/s   |
| typescript | 564 ns          | 457 ns            | 1.77M ops/s    | 2.19M ops/s   |
| zig      | 12.07 us        | 37 ns             | 82.84K ops/s   | 27.03M ops/s  |

### u64

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 70 ns           | 28 ns             | 14.29M ops/s   | 35.71M ops/s  |
| cpp      | 156 ns          | 22 ns             | 6.41M ops/s    | 45.28M ops/s  |
| csharp   | 107 ns          | 45 ns             | 9.38M ops/s    | 22.39M ops/s  |
| dart     | 13.52 us        | 2.44 us           | 73.99K ops/s   | 409.17K ops/s |
| elixir   | 286 ns          | 62 ns             | 3.50M ops/s    | 16.19M ops/s  |
| go       | 294 ns          | 42 ns             | 3.40M ops/s    | 23.81M ops/s  |
| java     | 1.43 us         | 219 ns            | 697.25K ops/s  | 4.56M ops/s   |
| kotlin   | 1.38 us         | 179 ns            | 0 ops/s        | 0 ops/s       |
| python   | 548 ns          | 517 ns            | 1.82M ops/s    | 1.93M ops/s   |
| ruby     | 756 ns          | 477 ns            | 1.32M ops/s    | 2.10M ops/s   |
| rust     | Error: invalid type: string "18446744              |
| swift    | 2.62 us         | 1.45 us           | 381.63K ops/s  | 690.19K ops/s |
| typescript | 990 ns          | 1.11 us           | 1.01M ops/s    | 899.16K ops/s |
| zig      | 11.60 us        | 44 ns             | 86.18K ops/s   | 22.73M ops/s  |

### u128

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 53 ns           | 21 ns             | 18.87M ops/s   | 47.62M ops/s  |
| cpp      | 177 ns          | 48 ns             | 5.65M ops/s    | 20.87M ops/s  |
| csharp   | 50 ns           | 24 ns             | 20.05M ops/s   | 42.54M ops/s  |
| dart     | 7.49 us         | 17.36 us          | 133.48K ops/s  | 57.62K ops/s  |
| elixir   | 902 ns          | 62 ns             | 1.11M ops/s    | 16.18M ops/s  |
| go       | 856 ns          | 56 ns             | 1.17M ops/s    | 17.99M ops/s  |
| java     | 5.64 us         | 248 ns            | 177.44K ops/s  | 4.04M ops/s   |
| kotlin   | 594 ns          | 353 ns            | 0 ops/s        | 0 ops/s       |
| python   | 581 ns          | 586 ns            | 1.72M ops/s    | 1.71M ops/s   |
| ruby     | 1.60 us         | 2.56 us           | 626.17K ops/s  | 390.47K ops/s |
| rust     | Error: invalid type: string "34028236              |
| swift    | 154 ns          | 147 ns            | 6.50M ops/s    | 6.80M ops/s   |
| typescript | 1.28 us         | 932 ns            | 779.38K ops/s  | 1.07M ops/s   |
| zig      | 12.15 us        | 36 ns             | 82.28K ops/s   | 27.78M ops/s  |

### i8

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 50 ns           | 26 ns             | 20.00M ops/s   | 38.46M ops/s  |
| cpp      | 40 ns           | 23 ns             | 25.24M ops/s   | 44.12M ops/s  |
| csharp   | 42 ns           | 24 ns             | 24.07M ops/s   | 42.48M ops/s  |
| dart     | 32 ns           | 0 ns              | 31.25M ops/s   | 0 ops/s       |
| elixir   | 131 ns          | 64 ns             | 7.61M ops/s    | 15.62M ops/s  |
| go       | 64 ns           | 22 ns             | 15.64M ops/s   | 45.62M ops/s  |
| java     | 102 ns          | 87 ns             | 9.81M ops/s    | 11.50M ops/s  |
| kotlin   | 506 ns          | 54 ns             | 0 ops/s        | 0 ops/s       |
| python   | 412 ns          | 526 ns            | 2.43M ops/s    | 1.90M ops/s   |
| ruby     | 1.64 us         | 620 ns            | 610.13K ops/s  | 1.61M ops/s   |
| rust     | 21 ns           | 21 ns             | 47.80M ops/s   | 47.72M ops/s  |
| swift    | 162 ns          | 147 ns            | 6.16M ops/s    | 6.79M ops/s   |
| typescript | 564 ns          | 346 ns            | 1.77M ops/s    | 2.89M ops/s   |
| zig      | 121.68 us       | 42 ns             | 8.22K ops/s    | 23.81M ops/s  |

### i16

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 52 ns           | 29 ns             | 19.23M ops/s   | 34.48M ops/s  |
| cpp      | 77 ns           | 25 ns             | 13.05M ops/s   | 40.13M ops/s  |
| csharp   | 43 ns           | 23 ns             | 23.23M ops/s   | 42.64M ops/s  |
| dart     | 175 ns          | 3 ns              | 5.71M ops/s    | 333.33M ops/s |
| elixir   | 134 ns          | 58 ns             | 7.45M ops/s    | 17.18M ops/s  |
| go       | 63 ns           | 24 ns             | 15.85M ops/s   | 41.75M ops/s  |
| java     | 170 ns          | 88 ns             | 5.87M ops/s    | 11.30M ops/s  |
| kotlin   | 674 ns          | 60 ns             | 0 ops/s        | 0 ops/s       |
| python   | 489 ns          | 553 ns            | 2.05M ops/s    | 1.81M ops/s   |
| ruby     | 796 ns          | 1.25 us           | 1.26M ops/s    | 800.00K ops/s |
| rust     | 22 ns           | 20 ns             | 46.42M ops/s   | 49.18M ops/s  |
| swift    | 163 ns          | 147 ns            | 6.14M ops/s    | 6.79M ops/s   |
| typescript | 475 ns          | 289 ns            | 2.10M ops/s    | 3.47M ops/s   |
| zig      | 16.97 us        | 40 ns             | 58.92K ops/s   | 25.00M ops/s  |

### i32

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 50 ns           | 25 ns             | 20.00M ops/s   | 40.00M ops/s  |
| cpp      | 123 ns          | 26 ns             | 8.10M ops/s    | 38.21M ops/s  |
| csharp   | 42 ns           | 25 ns             | 23.69M ops/s   | 40.61M ops/s  |
| dart     | 12 ns           | 74 ns             | 83.33M ops/s   | 13.51M ops/s  |
| elixir   | 139 ns          | 66 ns             | 7.18M ops/s    | 15.19M ops/s  |
| go       | 63 ns           | 24 ns             | 15.77M ops/s   | 42.55M ops/s  |
| java     | 153 ns          | 116 ns            | 6.53M ops/s    | 8.62M ops/s   |
| kotlin   | 246 ns          | 106 ns            | 0 ops/s        | 0 ops/s       |
| python   | 526 ns          | 576 ns            | 1.90M ops/s    | 1.74M ops/s   |
| ruby     | 592 ns          | 543 ns            | 1.69M ops/s    | 1.84M ops/s   |
| rust     | 21 ns           | 21 ns             | 46.87M ops/s   | 47.91M ops/s  |
| swift    | 165 ns          | 148 ns            | 6.06M ops/s    | 6.76M ops/s   |
| typescript | 1.48 us         | 234 ns            | 676.29K ops/s  | 4.27M ops/s   |
| zig      | 70.57 us        | 50 ns             | 14.17K ops/s   | 20.00M ops/s  |

### i64

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 53 ns           | 23 ns             | 18.87M ops/s   | 43.48M ops/s  |
| cpp      | 176 ns          | 29 ns             | 5.68M ops/s    | 35.03M ops/s  |
| csharp   | 53 ns           | 23 ns             | 18.75M ops/s   | 43.25M ops/s  |
| dart     | 5.92 us         | 44 ns             | 168.95K ops/s  | 22.73M ops/s  |
| elixir   | 308 ns          | 127 ns            | 3.24M ops/s    | 7.86M ops/s   |
| go       | 269 ns          | 26 ns             | 3.72M ops/s    | 38.15M ops/s  |
| java     | 1.20 us         | 91 ns             | 834.04K ops/s  | 10.94M ops/s  |
| kotlin   | 940 ns          | 73 ns             | 0 ops/s        | 0 ops/s       |
| python   | 616 ns          | 1.64 us           | 1.62M ops/s    | 609.22K ops/s |
| ruby     | 901 ns          | 650 ns            | 1.11M ops/s    | 1.54M ops/s   |
| rust     | Error: invalid type: string "-9223372              |
| swift    | 148 ns          | 137 ns            | 6.76M ops/s    | 7.29M ops/s   |
| typescript | 756 ns          | 515 ns            | 1.32M ops/s    | 1.94M ops/s   |
| zig      | 97.16 us        | 69 ns             | 10.29K ops/s   | 14.49M ops/s  |

### i128

| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |
|----------|-----------------|-------------------|----------------|---------------|
| c        | 53 ns           | 30 ns             | 18.87M ops/s   | 33.33M ops/s  |
| cpp      | 212 ns          | 52 ns             | 4.72M ops/s    | 19.09M ops/s  |
| csharp   | 50 ns           | 27 ns             | 20.03M ops/s   | 37.55M ops/s  |
| dart     | 7.76 us         | 1.00 us           | 128.78K ops/s  | 999.00K ops/s |
| elixir   | 393 ns          | 65 ns             | 2.54M ops/s    | 15.29M ops/s  |
| go       | 515 ns          | 105 ns            | 1.94M ops/s    | 9.55M ops/s   |
| java     | 1.04 us         | 171 ns            | 962.75K ops/s  | 5.84M ops/s   |
| kotlin   | 198 ns          | 93 ns             | 0 ops/s        | 0 ops/s       |
| python   | 644 ns          | 633 ns            | 1.55M ops/s    | 1.58M ops/s   |
| ruby     | 1.40 us         | 1.79 us           | 715.31K ops/s  | 559.28K ops/s |
| rust     | Error: invalid type: string "-1701411              |
| swift    | 157 ns          | 137 ns            | 6.38M ops/s    | 7.29M ops/s   |
| typescript | 1.12 us         | 989 ns            | 889.80K ops/s  | 1.01M ops/s   |
| zig      | 11.79 us        | 39 ns             | 84.85K ops/s   | 25.64M ops/s  |

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