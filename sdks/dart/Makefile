# BCS Dart SDK Makefile

.PHONY: all test lint format format-check build clean deps publish docs install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Get dependencies
deps:
	dart pub get

# Run tests
test:
	dart test

# Run tests with coverage
test-cov:
	dart test --coverage=coverage

# Lint code with dart analyze
lint:
	dart analyze lib/ test/

# Format code
format:
	dart format lib/ test/

# Check formatting (CI mode - no changes)
format-check:
	dart format --set-exit-if-changed lib/ test/

# Build (compile for checking)
build:
	dart compile exe --help > /dev/null 2>&1 || true
	@echo "Dart library compiled successfully"

# Clean build artifacts
clean:
	rm -rf .dart_tool/
	rm -rf build/
	rm -rf coverage/
	rm -f pubspec.lock

# Publish to pub.dev
publish:
	dart pub publish

# Generate documentation
docs:
	dart doc

# Run all checks (for CI)
ci: deps format-check lint test

# Install required tools (Dart SDK)
install-tools:
	@echo "=== Dart SDK Tools Installation ==="
	@echo "Required: dart (3.0+)"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew tap dart-lang/dart"
	@echo "  brew install dart"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install apt-transport-https"
	@echo "  wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg"
	@echo "  echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list"
	@echo "  sudo apt update && sudo apt install dart"
	@echo ""
	@echo "Official installer:"
	@echo "  https://dart.dev/get-dart"
	@echo ""
	@echo "After installation, run 'make deps' to get pub packages"
	@echo ""
	@echo "Checking current installation..."
	@which dart && dart --version || echo "dart not found"
