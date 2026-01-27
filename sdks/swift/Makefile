# BCS Swift SDK Makefile

.PHONY: all test lint format format-check build clean deps publish docs install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Install/update dependencies
deps:
	@echo "Swift dependencies managed via Swift Package Manager"
	swift package resolve

# Run tests
test:
	swift test

# Lint with SwiftLint (if available)
lint:
	@if command -v swiftlint > /dev/null; then \
		swiftlint lint Sources Tests; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Format code with swift-format (if available)
format:
	@if command -v swift-format > /dev/null; then \
		swift-format format -i -r Sources Tests; \
	else \
		echo "swift-format not installed. Install with: brew install swift-format"; \
	fi

# Check formatting (CI mode)
format-check:
	@if command -v swift-format > /dev/null; then \
		swift-format lint -r Sources Tests; \
	else \
		echo "swift-format not installed, skipping format check"; \
	fi

# Build library
build:
	swift build -c release

# Build debug
build-debug:
	swift build

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Generate documentation (requires swift-docc-plugin)
docs:
	swift package generate-documentation

# Publish (Swift packages are typically distributed via git tags)
publish:
	@echo "Swift packages are published via git tags."
	@echo "To publish:"
	@echo "  1. Update version in Package.swift"
	@echo "  2. Create a git tag: git tag swift-v1.0.0"
	@echo "  3. Push the tag: git push origin swift-v1.0.0"

# Run tests with verbose output
test-verbose:
	swift test --verbose

# Show package info
info:
	swift package describe

# Update dependencies
update:
	swift package update

# Run all checks (for CI)
ci: deps format-check lint test

# Install required tools (Swift, swift-format, SwiftLint)
install-tools:
	@echo "=== Swift SDK Tools Installation ==="
	@echo "Required: swift (5.9+), swift-format, swiftlint"
	@echo ""
	@echo "macOS:"
	@echo "  Swift is included with Xcode. Install Xcode from the App Store."
	@echo "  xcode-select --install  # Install command line tools"
	@echo "  brew install swift-format swiftlint"
	@echo ""
	@echo "Linux (Ubuntu/Debian):"
	@echo "  # Download from https://swift.org/download/"
	@echo "  # Or use swiftly: https://github.com/swift-server/swiftly"
	@echo "  curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash"
	@echo "  swiftly install latest"
	@echo ""
	@echo "After installation, run 'make deps' to resolve Swift packages"
	@echo ""
	@echo "Checking current installation..."
	@which swift && swift --version | head -1 || echo "swift not found"
	@which swift-format && swift-format --version || echo "swift-format not found"
	@which swiftlint && swiftlint version || echo "swiftlint not found"
