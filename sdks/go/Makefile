# BCS Go SDK Makefile

.PHONY: all test lint format format-check build clean deps tidy vet generate publish install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Install dependencies
deps:
	go mod download
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run tests
test:
	TEST_VECTORS=$(TEST_VECTORS) go test -v ./...

# Run tests with coverage
test-cov:
	TEST_VECTORS=$(TEST_VECTORS) go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Lint code with golangci-lint
lint:
	golangci-lint run ./...

# Format code with gofmt
format:
	gofmt -s -w .

# Check formatting (CI mode - no changes)
format-check:
	@test -z "$$(gofmt -l .)" || (echo "Files need formatting:" && gofmt -l . && exit 1)

# Build (verify compilation)
build:
	go build ./...

# Clean build artifacts
clean:
	go clean
	rm -f coverage.out coverage.html

# Tidy dependencies
tidy:
	go mod tidy

# Run go vet
vet:
	go vet ./...

# Generate (if needed)
generate:
	go generate ./...

# Publish (Go modules are published via git tags)
publish:
	@echo "Go modules are published via git tags."
	@echo "To publish:"
	@echo "  1. Update version in go.mod (if needed)"
	@echo "  2. Create a git tag: git tag go-v1.0.0"
	@echo "  3. Push the tag: git push origin go-v1.0.0"

# Run all checks (for CI)
ci: deps format-check lint test

# Install required tools (Go, golangci-lint)
install-tools:
	@echo "=== Go SDK Tools Installation ==="
	@echo "Required: go (1.21+), golangci-lint"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install go golangci-lint"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install golang-go"
	@echo "  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b \$$(go env GOPATH)/bin"
	@echo ""
	@echo "Official Go installer:"
	@echo "  https://go.dev/dl/"
	@echo ""
	@echo "After installation, run 'make deps' to download module dependencies"
	@echo ""
	@echo "Checking current installation..."
	@which go && go version || echo "go not found"
	@which golangci-lint && golangci-lint --version || echo "golangci-lint not found (will be installed by 'make deps')"
