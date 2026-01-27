# BCS TypeScript SDK Makefile

.PHONY: all test lint format format-check build clean publish deps typecheck install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Run all checks (for CI)
ci: deps format-check lint test

# Install dependencies
deps:
	npm install

# Run tests
test: deps
	TEST_VECTORS=$(TEST_VECTORS) npm test

# Lint code
lint: deps
	npm run lint

# Type checking
typecheck: deps
	npm run typecheck

# Format code
format: deps
	npm run format

# Check formatting (CI mode - no changes)
format-check: deps
	npm run format:check

# Build package
build: deps
	npm run build

# Clean build artifacts
clean:
	rm -rf dist node_modules .turbo coverage

# Publish to npm
publish: build
	npm publish --access public

# Install required tools (Node.js, npm)
install-tools:
	@echo "=== TypeScript SDK Tools Installation ==="
	@echo "Required: node (18+), npm"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install node"
	@echo ""
	@echo "Ubuntu/Debian (via NodeSource):"
	@echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
	@echo "  sudo apt install nodejs"
	@echo ""
	@echo "Using nvm (recommended):"
	@echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
	@echo "  nvm install 20"
	@echo ""
	@echo "After installation, run 'make deps' to install npm packages"
	@echo ""
	@echo "Checking current installation..."
	@node --version 2>/dev/null && echo "  node found" || echo "  node NOT FOUND"
	@which npm >/dev/null 2>&1 && echo "  npm found at $$(which npm)" || echo "  npm NOT FOUND"
