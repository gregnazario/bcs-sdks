# BCS Ruby SDK Makefile

.PHONY: all test lint format format-check build clean deps publish docs console install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Install dependencies
deps:
	bundle install

# Run tests
test:
	bundle exec ruby -Ilib:spec spec/bcs_spec.rb

# Lint code with RuboCop
lint:
	bundle exec rubocop lib/ spec/

# Format code with RuboCop auto-correct
format:
	bundle exec rubocop -a lib/ spec/

# Check formatting (CI mode - no changes)
format-check:
	bundle exec rubocop lib/ spec/

# Build gem
build:
	gem build bcs.gemspec

# Clean build artifacts
clean:
	rm -f *.gem
	rm -rf pkg/
	rm -rf coverage/
	rm -rf .bundle/

# Publish to RubyGems
publish: build
	gem push bcs-*.gem

# Run tests with verbose output
test-verbose:
	bundle exec ruby -Ilib:spec spec/bcs_spec.rb -v

# Interactive console
console:
	bundle exec irb -Ilib -rbcs

# Generate documentation
docs:
	bundle exec yard doc lib/

# Run all checks (for CI)
ci: deps format-check lint test

# Install required tools (Ruby, Bundler)
install-tools:
	@echo "=== Ruby SDK Tools Installation ==="
	@echo "Required: ruby (3.0+), bundler, rubocop"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install ruby"
	@echo "  gem install bundler"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install ruby-full"
	@echo "  gem install bundler"
	@echo ""
	@echo "Using rbenv (recommended):"
	@echo "  brew install rbenv  # or: git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
	@echo "  rbenv install 3.2.0"
	@echo "  rbenv global 3.2.0"
	@echo "  gem install bundler"
	@echo ""
	@echo "After installation, run 'make deps' to install gems (rubocop, minitest, etc.)"
	@echo ""
	@echo "Checking current installation..."
	@which ruby && ruby --version || echo "ruby not found"
	@which bundle && bundle --version || echo "bundler not found"
