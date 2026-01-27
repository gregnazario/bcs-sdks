# BCS Multi-Language SDKs - Root Makefile
# Delegates to per-language Makefiles in sdks/*/

# Primary languages (in priority order)
LANGUAGES := python elixir java csharp cpp swift ruby c dart

# All languages
ALL_LANGUAGES := $(LANGUAGES)

.PHONY: all help test lint format format-check build clean publish deps install-tools
.PHONY: $(ALL_LANGUAGES) FORCE

# Default target
all: format-check lint test

help:
	@echo "BCS Multi-Language SDKs"
	@echo ""
	@echo "Global targets:"
	@echo "  make test           - Run tests for all SDKs"
	@echo "  make lint           - Run linters for all SDKs"
	@echo "  make format         - Format code in all SDKs"
	@echo "  make format-check   - Check formatting in all SDKs (CI mode)"
	@echo "  make build          - Build all SDK packages"
	@echo "  make clean          - Clean all build artifacts"
	@echo "  make deps           - Install dependencies for all SDKs"
	@echo "  make install-tools  - Show installation instructions for all SDKs"
	@echo ""
	@echo "Per-language targets:"
	@echo "  make test-python         - Run Python SDK tests"
	@echo "  make lint-elixir         - Run Elixir SDK linter"
	@echo "  make format-go           - Format Go SDK code"
	@echo "  make deps-rust           - Install Rust SDK dependencies"
	@echo "  make install-tools-java  - Show Java SDK tool installation"
	@echo "  make python              - Run all targets for Python SDK"
	@echo ""
	@echo "Available languages:"
	@echo "  $(LANGUAGES)"

# =============================================================================
# GLOBAL TARGETS - Run across all SDKs
# =============================================================================

# Run all tests
test: $(addprefix test-,$(LANGUAGES))
	@echo "All tests completed"

# Run all linters (fail on errors only)
lint: $(addprefix lint-,$(LANGUAGES))
	@echo "All linting completed"

# Format all code
format: $(addprefix format-,$(LANGUAGES))
	@echo "All formatting completed"

# Check formatting (CI mode - no changes)
format-check: $(addprefix format-check-,$(LANGUAGES))
	@echo "All format checks completed"

# Build all packages
build: $(addprefix build-,$(LANGUAGES))
	@echo "All builds completed"

# Clean all
clean: $(addprefix clean-,$(LANGUAGES))
	@echo "All cleaning completed"

# Install all dependencies
deps: $(addprefix deps-,$(LANGUAGES))
	@echo "All dependencies installed"

# Show install instructions for all tools
install-tools: $(addprefix install-tools-,$(LANGUAGES))
	@echo ""
	@echo "=== Installation Complete ==="
	@echo "Run 'make deps' to install language-specific package dependencies"

# =============================================================================
# PER-LANGUAGE DELEGATION
# =============================================================================

# Individual language shortcut (runs all targets)
$(ALL_LANGUAGES):
	@if [ -d "sdks/$@" ]; then \
		echo "=== Running all targets for $@ ==="; \
		$(MAKE) -C sdks/$@ all; \
	else \
		echo "SDK not yet implemented: $@"; \
	fi

# Test targets
test-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Testing $* ==="; \
		if $(MAKE) -C sdks/$* test; then \
			echo "=== Tests passed for $* ==="; \
		else \
			echo "=== Tests failed for $* ==="; \
			exit 1; \
		fi; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Lint targets
lint-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Linting $* ==="; \
		if $(MAKE) -C sdks/$* lint; then \
			echo "=== Lint passed for $* ==="; \
		else \
			echo "=== Lint failed for $* ==="; \
			exit 1; \
		fi; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Format targets
format-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Formatting $* ==="; \
		$(MAKE) -C sdks/$* format; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Format check targets
format-check-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Checking format for $* ==="; \
		$(MAKE) -C sdks/$* format-check; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Build targets
build-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Building $* ==="; \
		$(MAKE) -C sdks/$* build; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Clean targets
clean-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Cleaning $* ==="; \
		$(MAKE) -C sdks/$* clean; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Publish targets (typically run by CI)
publish-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Publishing $* ==="; \
		$(MAKE) -C sdks/$* publish; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Deps targets
deps-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo "=== Installing dependencies for $* ==="; \
		$(MAKE) -C sdks/$* deps; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# Install tools targets
install-tools-%: FORCE
	@if [ -d "sdks/$*" ]; then \
		echo ""; \
		$(MAKE) -C sdks/$* install-tools; \
	else \
		echo "SDK not yet implemented: $*"; \
	fi

# =============================================================================
# UTILITY TARGETS
# =============================================================================

FORCE:

# Validate test vectors JSON
validate-vectors:
	@echo "Validating test vectors..."
	@python -m json.tool test-vectors/bcs-comprehensive.json > /dev/null
	@echo "Test vectors are valid JSON"

# List implemented SDKs
list-sdks:
	@echo "Implemented SDKs:"
	@for lang in $(ALL_LANGUAGES); do \
		if [ -d "sdks/$$lang" ]; then \
			echo "  ✓ $$lang"; \
		else \
			echo "  ✗ $$lang (not implemented)"; \
		fi \
	done

# Run tests for implemented SDKs only
test-implemented:
	@for lang in $(ALL_LANGUAGES); do \
		if [ -d "sdks/$$lang" ]; then \
			$(MAKE) -C sdks/$$lang test || exit 1; \
		fi \
	done

# CI target - what GitHub Actions will run
ci: validate-vectors format-check lint test
	@echo "CI checks passed"

# =============================================================================
# E2E TESTS - Cross-language roundtrip verification
# =============================================================================

.PHONY: e2e-test e2e-generate e2e-clean

# Run all e2e roundtrip tests
e2e-test:
	@echo "Running E2E roundtrip tests..."
	@$(MAKE) -C e2e-tests test

# Generate reference test vectors only
e2e-generate:
	@$(MAKE) -C e2e-tests generate

# Clean e2e test artifacts
e2e-clean:
	@$(MAKE) -C e2e-tests clean

# Per-language e2e tests
e2e-test-%:
	@$(MAKE) -C e2e-tests test-$*
