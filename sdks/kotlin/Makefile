# BCS Kotlin SDK Makefile

.PHONY: all test lint format format-check build clean deps publish docs install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Gradle wrapper (use local if available, fallback to system)
GRADLE := ./gradlew
ifeq (,$(wildcard $(GRADLE)))
    GRADLE := gradle
endif

# Default target
all: format-check lint test

# Get dependencies
deps:
	$(GRADLE) dependencies

# Build library
build:
	$(GRADLE) build -x test

# Run tests
test:
	$(GRADLE) test

# Lint code with ktlint
lint:
	@if command -v ktlint >/dev/null 2>&1; then \
		ktlint "src/**/*.kt"; \
	else \
		echo "ktlint not found, using gradle check"; \
		$(GRADLE) check -x test || true; \
	fi

# Format code with ktlint
format:
	@if command -v ktlint >/dev/null 2>&1; then \
		ktlint -F "src/**/*.kt" || true; \
	else \
		echo "ktlint not found, skipping format"; \
	fi

# Check formatting (CI mode - no changes)
format-check:
	@if command -v ktlint >/dev/null 2>&1; then \
		ktlint "src/**/*.kt"; \
	else \
		echo "ktlint not found, skipping format-check"; \
	fi

# Clean build artifacts
clean:
	$(GRADLE) clean
	rm -rf build/

# Publish to Maven
publish: build
	$(GRADLE) publish

# Generate documentation
docs:
	$(GRADLE) dokkaHtml || echo "Dokka not configured"

# Run all checks (for CI)
ci: deps build format-check lint test

# Install required tools (JDK, Gradle, ktlint)
install-tools:
	@echo "=== Kotlin SDK Tools Installation ==="
	@echo "Required: java (JDK 17+), gradle, ktlint"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install openjdk@17 gradle ktlint"
	@echo "  sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install openjdk-17-jdk"
	@echo "  # Install Gradle: https://gradle.org/install/"
	@echo "  # Install ktlint: https://pinterest.github.io/ktlint/install/cli/"
	@echo ""
	@echo "Using SDKMAN (recommended):"
	@echo "  curl -s https://get.sdkman.io | bash"
	@echo "  sdk install java 17.0.9-tem"
	@echo "  sdk install gradle"
	@echo "  sdk install ktlint"
	@echo ""
	@echo "After installation, run 'make deps' to download Gradle dependencies"
	@echo ""
	@echo "Checking current installation..."
	@which java && java -version 2>&1 | head -1 || echo "java not found"
	@which gradle && gradle --version | grep Gradle || echo "gradle not found"
	@which ktlint && ktlint --version || echo "ktlint not found"
