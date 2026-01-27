# BCS Elixir SDK Makefile

.PHONY: all test test-cov lint format format-check build clean publish deps dialyzer docs iex check-mix install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Check for mix command (Elixir build tool)
MIX ?= $(firstword $(shell command -v mix 2>/dev/null))

# Default target
all: format-check lint test

# Run all checks (for CI)
ci: deps format-check lint test

# Check if mix is available
check-mix:
	@if [ -z "$(MIX)" ]; then \
		echo "Error: mix command not found. Please install Elixir."; \
		echo "Visit https://elixir-lang.org/install.html for installation instructions."; \
		exit 1; \
	fi

# Install dependencies
deps: check-mix
	$(MIX) deps.get

# Run tests
test: deps
	TEST_VECTORS=$(TEST_VECTORS) $(MIX) test

# Run tests with coverage
test-cov: deps
	TEST_VECTORS=$(TEST_VECTORS) $(MIX) coveralls

# Lint code (fail on errors only)
lint: deps
	$(MIX) credo --min-priority=high
	$(MIX) credo --strict || true  # Full check as warning

# Run dialyzer for type checking
dialyzer: deps
	mkdir -p priv/plts
	$(MIX) dialyzer

# Format code
format: check-mix
	$(MIX) format

# Check formatting (CI mode - no changes)
format-check: check-mix
	$(MIX) format --check-formatted

# Build package
build: deps
	$(MIX) compile

# Clean build artifacts
clean:
	@if [ -n "$(MIX)" ]; then \
		$(MIX) clean; \
	fi
	rm -rf _build deps .elixir_ls priv/plts
	rm -rf cover

# Publish to Hex
publish: build
	$(MIX) hex.publish

# Generate documentation
docs: deps
	$(MIX) docs

# Interactive shell
iex: deps
	iex -S $(MIX)

# Install required tools (Elixir, Erlang)
install-tools:
	@echo "=== Elixir SDK Tools Installation ==="
	@echo "Required: erlang (24+), elixir (1.14+), mix, hex"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install elixir"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb"
	@echo "  sudo dpkg -i erlang-solutions_2.0_all.deb"
	@echo "  sudo apt update && sudo apt install esl-erlang elixir"
	@echo ""
	@echo "Using asdf (recommended):"
	@echo "  asdf plugin add erlang"
	@echo "  asdf plugin add elixir"
	@echo "  asdf install erlang latest"
	@echo "  asdf install elixir latest"
	@echo ""
	@echo "After installation, run 'make deps' to install Hex packages (credo, etc.)"
	@echo ""
	@echo "Checking current installation..."
	@which elixir && elixir --version || echo "elixir not found"
	@which mix && mix --version || echo "mix not found"
