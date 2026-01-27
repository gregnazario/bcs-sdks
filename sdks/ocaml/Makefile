# BCS OCaml SDK Makefile

.PHONY: all test lint format format-check build clean deps publish docs install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Install dependencies
deps:
	opam install . --deps-only --with-test -y

# Build library
build:
	dune build

# Run tests
test:
	dune runtest

# Lint code (using dune's built-in checking)
lint:
	@if command -v ocamllint >/dev/null 2>&1; then \
		ocamllint lib/*.ml; \
	else \
		dune build @check; \
	fi

# Format code with ocamlformat
format:
	@if command -v ocamlformat >/dev/null 2>&1; then \
		dune fmt; \
	else \
		echo "ocamlformat not found, skipping format"; \
	fi

# Check formatting (CI mode - no changes)
format-check:
	@if command -v ocamlformat >/dev/null 2>&1; then \
		dune fmt --diff; \
	else \
		echo "ocamlformat not found, skipping format-check"; \
	fi

# Clean build artifacts
clean:
	dune clean
	rm -rf _build

# Publish to opam
publish: build
	opam publish

# Generate documentation
docs:
	dune build @doc

# Run all checks (for CI)
ci: deps build format-check lint test

# Install required tools (OCaml, opam, dune, ocamlformat)
install-tools:
	@echo "=== OCaml SDK Tools Installation ==="
	@echo "Required: ocaml (4.14+), opam, dune, ocamlformat"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install opam"
	@echo "  opam init"
	@echo "  opam install dune ocamlformat"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install opam"
	@echo "  opam init"
	@echo "  opam install dune ocamlformat"
	@echo ""
	@echo "Official installer:"
	@echo "  bash -c \"sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)\""
	@echo "  opam init"
	@echo "  eval \$$(opam env)"
	@echo "  opam install dune ocamlformat"
	@echo ""
	@echo "After installation, run 'make deps' to install opam dependencies"
	@echo ""
	@echo "Checking current installation..."
	@which ocaml && ocaml -version || echo "ocaml not found"
	@which opam && opam --version || echo "opam not found"
	@which dune && dune --version || echo "dune not found"
	@which ocamlformat && ocamlformat --version || echo "ocamlformat not found"
