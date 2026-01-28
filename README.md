# BCS Multi-Language SDKs

[![CI](https://github.com/bcs-sdks/bcs-sdks/actions/workflows/ci.yml/badge.svg)](https://github.com/bcs-sdks/bcs-sdks/actions/workflows/ci.yml)

Binary Canonical Serialization (BCS) implementations across 15 programming languages.

## What is BCS?

BCS is a deterministic binary serialization format that guarantees **canonical representation** - every value has exactly one valid serialized form. This property is essential for:

- Cryptographic hashing of data structures
- Signature verification
- Consensus in blockchain systems

BCS was developed for the Diem (formerly Libra) blockchain and is used by Aptos, Sui, and other systems.

## Specification

See [spec/BCS.md](spec/BCS.md) for the formal specification using RFC 2119 language (SHALL, SHOULD, MAY).

## Available SDKs

| Language | Directory | Tests | Status |
|----------|-----------|-------|--------|
| [C](sdks/c) | `sdks/c` | ✅ Pass | Complete |
| [C++](sdks/cpp) | `sdks/cpp` | ✅ 28 Pass | Complete |
| [C#](sdks/csharp) | `sdks/csharp` | ✅ 35 Pass | Complete |
| [Dart](sdks/dart) | `sdks/dart` | ✅ 62 Pass | Complete |
| [Elixir](sdks/elixir) | `sdks/elixir` | ✅ 218 Pass | Complete |
| [Go](sdks/go) | `sdks/go` | ✅ Pass | Complete |
| [Java](sdks/java) | `sdks/java` | ✅ 52 Pass | Complete |
| [Kotlin](sdks/kotlin) | `sdks/kotlin` | ✅ Pass | Complete |
| [OCaml](sdks/ocaml) | `sdks/ocaml` | ✅ 39 Pass | Complete |
| [Python](sdks/python) | `sdks/python` | ✅ 150 Pass | Complete |
| [Ruby](sdks/ruby) | `sdks/ruby` | ✅ 53 Pass | Complete |
| [Rust](sdks/rust) | `sdks/rust` | ✅ 58 Pass | Complete |
| [Swift](sdks/swift) | `sdks/swift` | ✅ 68 Pass | Complete |
| [TypeScript](sdks/typescript) | `sdks/typescript` | ✅ 48 Pass | Complete |
| [Zig](sdks/zig) | `sdks/zig` | ✅ Pass | Complete |

See [SDK_AUDIT_REPORT.md](SDK_AUDIT_REPORT.md) for detailed security and functionality analysis.
See [DIFFERENCES.md](DIFFERENCES.md) for implementation differences across languages.

## Two-Tier API Design

Each SDK provides two levels of API:

### Tier 1: Manual API (Common Base)

Explicit control with consistent method names across all languages:

```python
# Python
s = BcsSerializer()
s.write_u64(100)
s.write_string("hello")
data = s.to_bytes()

d = BcsDeserializer(data)
value1 = d.read_u64()
value2 = d.read_string()
```

```typescript
// TypeScript
const s = new BcsSerializer();
s.writeU64(100n);
s.writeString("hello");
const data = s.toBytes();

const d = new BcsDeserializer(data);
const value1 = d.readU64();
const value2 = d.readString();
```

### Tier 2: Idiomatic API (Language-Specific)

Natural patterns for each language:

```python
# Python with decorators
@bcs_struct
@dataclass
class Transfer:
    sender: AccountAddress
    recipient: AccountAddress
    amount: u64

transfer = Transfer(sender=addr1, recipient=addr2, amount=1000)
data = to_bcs(transfer)
```

```rust
// Rust with Serde
#[derive(Serialize, Deserialize)]
struct Transfer {
    sender: AccountAddress,
    recipient: AccountAddress,
    amount: u64,
}

let data = bcs::to_bytes(&transfer)?;
```

## Quick Start

### Using Make

```bash
# Run all SDK tests
make test

# Run specific SDK tests
make test-python      # 150 tests
make test-typescript  # 48 tests
make test-rust        # 58 tests
make test-go          # All tests
make test-java        # 52 tests
make test-kotlin      # All tests
make test-cpp         # 28 tests
make test-swift       # 68 tests
make test-c           # All tests
make test-ruby        # 53 tests
make test-dart        # 62 tests
make test-elixir      # 218 tests
make test-csharp      # 35 tests
make test-zig         # All tests
make test-ocaml       # 39 tests

# Format all code
make format

# Check formatting (CI mode)
make format-check
```

### Per-Language

```bash
cd sdks/python && make test
cd sdks/typescript && npm test
cd sdks/rust && cargo test
cd sdks/go && go test ./...
cd sdks/elixir && mix test
```

## Test Vectors

All SDKs validate against shared test vectors in [test-vectors/bcs-comprehensive.json](test-vectors/bcs-comprehensive.json).

## Supported Types

| Type | Description |
|------|-------------|
| bool | `0x00` = false, `0x01` = true |
| u8, u16, u32, u64, u128, u256 | Unsigned integers, little-endian |
| i8, i16, i32, i64, i128, i256 | Signed integers, two's complement |
| bytes | ULEB128 length + raw bytes |
| string | ULEB128 length + UTF-8 bytes |
| option\<T\> | `0x00` = None, `0x01` + value = Some |
| vector\<T\> | ULEB128 length + elements |
| fixed array | Elements without length prefix |
| struct | Fields in declaration order |
| enum | ULEB128 variant index + data |
| map | ULEB128 length + sorted key-value pairs |

## Constraints

- **MAX_SEQUENCE_LENGTH**: 2^31 - 1 (2,147,483,647)
- **MAX_CONTAINER_DEPTH**: 500 (nested structs/enums)
- **ULEB128**: Maximum u32 value, canonical encoding required

## Contributing

1. Fork the repository
2. Create your feature branch
3. Run `make format` and `make lint`
4. Submit a pull request

## License

Apache-2.0
