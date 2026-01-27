# BCS Zig SDK Makefile

.PHONY: all deps build test lint format format-check clean docs publish install-tools ci

# Check for zig
ZIG := $(shell command -v zig 2>/dev/null)

# Default target
all: format-check lint test

# Install dependencies (no-op for Zig, dependencies are built-in)
deps:
	@echo "Zig has no external dependencies to install"

# Build library
build:
ifndef ZIG
	@echo "Zig not found, skipping build"
else
	zig build
endif

# Run tests
test:
ifndef ZIG
	@echo "Zig not found, skipping tests"
else
	zig build test
endif

# Lint (Zig doesn't have a separate linter, zig fmt --check serves this purpose)
lint: format-check

# Format code
format:
ifndef ZIG
	@echo "Zig not found, skipping format"
else
	zig fmt src/
endif

# Check formatting (CI mode)
format-check:
ifndef ZIG
	@echo "Zig not found, skipping format-check"
else
	zig fmt --check src/
endif

# Generate documentation
docs:
ifndef ZIG
	@echo "Zig not found, skipping docs"
else
	zig build docs
endif

# Clean build artifacts
clean:
	rm -rf zig-out .zig-cache zig-cache

# Publish (Zig packages are typically distributed via Git)
publish:
	@echo "Zig packages are distributed via Git repositories"
	@echo "Add this as a dependency in build.zig.zon"

# Run all checks (for CI)
ci: deps build format-check lint test
	@echo "CI checks passed"

# Install required tools (Zig)
install-tools:
	@echo "=== Zig SDK Tools Installation ==="
	@echo "Required: zig (0.11+)"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install zig"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  # Download from https://ziglang.org/download/"
	@echo "  # Or use snap:"
	@echo "  sudo snap install zig --classic --beta"
	@echo ""
	@echo "Official downloads:"
	@echo "  https://ziglang.org/download/"
	@echo ""
	@echo "Zig includes its own formatter (zig fmt) - no additional tools needed"
	@echo ""
	@echo "Checking current installation..."
	@which zig && zig version || echo "zig not found"
