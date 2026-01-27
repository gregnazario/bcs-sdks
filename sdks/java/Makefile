# BCS Java SDK Makefile

.PHONY: all test lint format format-check build clean publish deps docs verify install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Google Java Format version
GJF_VERSION := 1.19.2
GJF_JAR := google-java-format-$(GJF_VERSION)-all-deps.jar
GJF_URL := https://github.com/google/google-java-format/releases/download/v$(GJF_VERSION)/$(GJF_JAR)

# Default target
all: format-check lint test

# Download google-java-format if not present
$(GJF_JAR):
	curl -LO $(GJF_URL)

# Install dependencies (download format tool)
deps: $(GJF_JAR)
	mvn dependency:resolve

# Run tests
test:
	mvn test -DTEST_VECTORS=$(TEST_VECTORS)

# Lint code with checkstyle
lint:
	mvn checkstyle:check

# Format code with google-java-format
format: $(GJF_JAR)
	java -jar $(GJF_JAR) --replace $$(find src -name "*.java")

# Check formatting (CI mode - no changes)
format-check: $(GJF_JAR)
	java -jar $(GJF_JAR) --dry-run --set-exit-if-changed $$(find src -name "*.java")

# Build package
build:
	mvn package -DskipTests

# Clean build artifacts
clean:
	mvn clean
	rm -f $(GJF_JAR)

# Publish to Maven Central
publish:
	mvn deploy -P release

# Generate Javadoc
docs:
	mvn javadoc:javadoc

# Verify (compile + test + package)
verify:
	mvn verify

# Run all checks (for CI)
ci: deps format-check lint test

# Install required tools (JDK, Maven)
install-tools:
	@echo "=== Java SDK Tools Installation ==="
	@echo "Required: java (JDK 11+), maven (3.6+)"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install openjdk@17 maven"
	@echo "  sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install openjdk-17-jdk maven"
	@echo ""
	@echo "Fedora:"
	@echo "  sudo dnf install java-17-openjdk-devel maven"
	@echo ""
	@echo "Using SDKMAN (recommended):"
	@echo "  curl -s https://get.sdkman.io | bash"
	@echo "  sdk install java 17.0.9-tem"
	@echo "  sdk install maven"
	@echo ""
	@echo "After installation, run 'make deps' to download google-java-format and Maven dependencies"
	@echo ""
	@echo "Checking current installation..."
	@which java && java -version 2>&1 | head -1 || echo "java not found"
	@which mvn && mvn --version | head -1 || echo "maven not found"
