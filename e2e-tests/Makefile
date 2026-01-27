# BCS E2E Roundtrip Tests Makefile

.PHONY: all test generate clean help benchmark report
.PHONY: test-python test-typescript test-go test-elixir test-rust test-ruby

# Default target
all: test

help:
	@echo "BCS E2E Roundtrip Tests"
	@echo ""
	@echo "Targets:"
	@echo "  make test           - Run all e2e tests"
	@echo "  make benchmark      - Run correctness tests and benchmarks"
	@echo "  make report         - Generate benchmark report (BENCHMARK_REPORT.md)"
	@echo "  make generate       - Generate reference test vectors"
	@echo "  make clean          - Clean generated files"
	@echo ""
	@echo "Per-language tests:"
	@echo "  make test-python    - Test Python SDK"
	@echo "  make test-typescript- Test TypeScript SDK"
	@echo "  make test-go        - Test Go SDK"
	@echo "  make test-elixir    - Test Elixir SDK"
	@echo "  make test-rust      - Test Rust SDK"
	@echo "  make test-ruby      - Test Ruby SDK"

# Ensure test-data directory exists
test-data:
	@mkdir -p test-data

# Generate reference test vectors using Rust
generate: test-data
	@echo "Generating reference test vectors..."
	@cd reference && cargo build --release 2>/dev/null
	@cd reference && cargo run --release 2>/dev/null > ../test-data/reference_vectors.json
	@echo "Test vectors written to test-data/reference_vectors.json"

# Run all tests
test: generate
	@echo "Running E2E roundtrip tests..."
	@python3 orchestrator.py -v

# Individual language tests
test-python: generate
	@echo "Testing Python SDK..."
	@python3 orchestrator.py -l python -v

test-typescript: generate
	@echo "Testing TypeScript SDK..."
	@python3 orchestrator.py -l typescript -v

test-go: generate
	@echo "Testing Go SDK..."
	@python3 orchestrator.py -l go -v

test-elixir: generate
	@echo "Testing Elixir SDK..."
	@python3 orchestrator.py -l elixir -v

test-rust: generate
	@echo "Testing Rust SDK roundtrip..."
	@python3 orchestrator.py -l rust -v

test-ruby: generate
	@echo "Testing Ruby SDK..."
	@python3 orchestrator.py -l ruby -v

test-swift: generate
	@echo "Testing Swift SDK..."
	@python3 orchestrator.py -l swift -v

test-kotlin: generate
	@echo "Testing Kotlin SDK..."
	@python3 orchestrator.py -l kotlin -v

test-csharp: generate
	@echo "Testing C# SDK..."
	@python3 orchestrator.py -l csharp -v

test-cpp: generate
	@echo "Testing C++ SDK..."
	@python3 orchestrator.py -l cpp -v

test-c: generate
	@echo "Testing C SDK..."
	@python3 orchestrator.py -l c -v

test-zig: generate
	@echo "Testing Zig SDK..."
	@python3 orchestrator.py -l zig -v

test-dart: generate
	@echo "Testing Dart SDK..."
	@python3 orchestrator.py -l dart -v

test-haskell: generate
	@echo "Testing Haskell SDK..."
	@python3 orchestrator.py -l haskell -v

test-ocaml: generate
	@echo "Testing OCaml SDK..."
	@python3 orchestrator.py -l ocaml -v

test-java: generate
	@echo "Testing Java SDK..."
	@python3 orchestrator.py -l java -v

# Clean generated files
clean:
	@rm -rf test-data
	@rm -rf reference/target
	@echo "Cleaned generated files"

# Build reference generator only
build-reference:
	@cd reference && cargo build --release

# Run benchmarks (correctness + performance)
benchmark: test-data generate
	@echo "Running benchmarks..."
	@python3 benchmark_orchestrator.py -v
	@echo "Benchmark results saved to test-data/benchmark_results.json"

# Run benchmarks for specific language
benchmark-python: test-data generate
	@echo "Benchmarking Python SDK..."
	@python3 benchmark_orchestrator.py -l python -v

benchmark-go: test-data generate
	@echo "Benchmarking Go SDK..."
	@python3 benchmark_orchestrator.py -l go -v

benchmark-rust: test-data generate
	@echo "Benchmarking Rust SDK..."
	@python3 benchmark_orchestrator.py -l rust -v

benchmark-typescript: test-data generate
	@echo "Benchmarking TypeScript SDK..."
	@python3 benchmark_orchestrator.py -l typescript -v

# Generate markdown report from benchmark results
report: test-data
	@echo "Generating benchmark report..."
	@python3 generate_report.py
	@echo "Report generated: ../BENCHMARK_REPORT.md"

# Run full benchmark suite and generate report
benchmark-report: benchmark report
	@echo "Full benchmark and report complete!"

# Correctness tests only (no benchmarks)
correctness: generate
	@echo "Running correctness tests only..."
	@python3 benchmark_orchestrator.py --correctness-only -v
