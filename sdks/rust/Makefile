# BCS Rust SDK Makefile

.PHONY: all test lint format format-check build clean publish deps bench docs audit update install-tools ci

# Path to shared test vectors (not used in Rust SDK which has its own tests)
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Install/update dependencies
deps:
	cargo fetch

# Run tests
test:
	cargo test

# Run tests with all features
test-all:
	cargo test --all-features

# Lint code with clippy
lint:
	cargo clippy --all-targets --all-features -- -D warnings

# Format code with rustfmt
format:
	cargo fmt

# Check formatting (CI mode - no changes)
format-check:
	cargo fmt -- --check

# Build library
build:
	cargo build --release

# Clean build artifacts
clean:
	cargo clean

# Run benchmarks
bench:
	cargo bench

# Publish to crates.io
publish:
	cargo publish

# Generate documentation
docs:
	cargo doc --no-deps

# Run clippy with pedantic warnings (informational)
lint-pedantic:
	cargo clippy --all-targets --all-features -- -W clippy::pedantic

# Check for security vulnerabilities
audit:
	cargo audit

# Update dependencies
update:
	cargo update

# Run all checks (for CI)
ci: deps format-check lint test

# Install required tools (Rust toolchain)
install-tools:
	@echo "=== Rust SDK Tools Installation ==="
	@echo "Required: rustc, cargo, clippy, rustfmt"
	@echo ""
	@echo "All platforms (recommended):"
	@echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
	@echo "  rustup component add clippy rustfmt"
	@echo ""
	@echo "macOS (Homebrew - alternative):"
	@echo "  brew install rust"
	@echo ""
	@echo "Optional (security auditing):"
	@echo "  cargo install cargo-audit"
	@echo ""
	@echo "After installation, run 'make deps' to fetch crate dependencies"
	@echo ""
	@echo "Checking current installation..."
	@which rustc && rustc --version || echo "rustc not found"
	@which cargo && cargo --version || echo "cargo not found"
	@cargo clippy --version 2>/dev/null || echo "clippy not found (run: rustup component add clippy)"
	@cargo fmt --version 2>/dev/null || echo "rustfmt not found (run: rustup component add rustfmt)"
