# BCS End-to-End Roundtrip Tests

This directory contains end-to-end tests that verify roundtrip serialization compatibility
between the reference Rust BCS implementation and all other language SDKs.

## How it Works

1. **Reference Generation**: The Rust program generates test vectors by serializing various
   data types to BCS format and outputs them as JSON.

2. **Roundtrip Testing**: Each language SDK:
   - Reads the Rust-generated BCS bytes
   - Deserializes them to native types
   - Re-serializes them back to BCS
   - Outputs the result

3. **Comparison**: The orchestrator compares each SDK's output to the original Rust output.
   A successful test means the bytes match exactly, proving interoperability.

## Running Tests

```bash
# Run all e2e tests
make test

# Generate reference vectors only
make generate

# Run specific language
make test-python
make test-typescript
make test-go

# Clean generated files
make clean
```

## Test Structure

```
e2e-tests/
├── Makefile              # Build and test orchestration
├── reference/            # Rust reference implementation
│   ├── Cargo.toml
│   └── src/main.rs       # Generates test vectors
├── runners/              # Per-language roundtrip runners
│   ├── python_runner.py
│   ├── typescript_runner.ts
│   ├── go_runner.go
│   └── ...
├── orchestrator.py       # Main test orchestrator
└── test-data/            # Generated test vectors (gitignored)
```

## Adding a New Language

1. Create a runner in `runners/` that:
   - Reads test vectors from stdin (JSON format)
   - For each test case, deserializes the BCS bytes
   - Re-serializes and outputs the result
   - Outputs JSON with the same structure

2. Add the language to the `LANGUAGES` list in `orchestrator.py`

3. Add make targets in `Makefile`

## Test Vector Format

```json
{
  "test_cases": [
    {
      "name": "u64_max",
      "type": "u64",
      "value": "18446744073709551615",
      "bcs_hex": "ffffffffffffffff"
    }
  ]
}
```

Each runner outputs the same format, and the orchestrator compares `bcs_hex` values.
