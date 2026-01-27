# BCS Python SDK Makefile

.PHONY: all test test-cov lint format format-check build clean publish deps typecheck dev-install venv install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Virtualenv configuration (override VENV_BIN for Windows)
# Prefer python3, fallback to python if needed.
PYTHON ?= $(firstword $(shell command -v python3 2>/dev/null) $(shell command -v python 2>/dev/null))
VENV ?= .venv
VENV_BIN ?= $(VENV)/bin
VENV_PY_FILE := $(VENV_BIN)/python
VENV_PY = $(shell if [ -x "$(VENV_BIN)/python3" ]; then echo "$(VENV_BIN)/python3"; else echo "$(VENV_PY_FILE)"; fi)

# Default target
all: format-check lint test

# Run all checks (for CI)
ci: deps format-check lint test

venv: $(VENV_PY_FILE)

$(VENV_PY_FILE):
	@if [ -z "$(PYTHON)" ]; then \
		echo "Python interpreter not found (python3 or python)"; \
		exit 1; \
	fi; \
	$(PYTHON) -m venv $(VENV)

# Install dependencies
deps: $(VENV_PY_FILE)
	$(VENV_PY) -m pip install -e ".[dev]"

# Run tests
test: $(VENV_PY_FILE)
	TEST_VECTORS=$(TEST_VECTORS) $(VENV_PY) -m pytest tests/ -v --tb=short

# Run tests with coverage
test-cov: $(VENV_PY_FILE)
	TEST_VECTORS=$(TEST_VECTORS) $(VENV_PY) -m pytest tests/ -v --cov=src/bcs --cov-report=term-missing

# Lint code (fail on errors only)
lint: $(VENV_PY_FILE)
	$(VENV_PY) -m ruff check src/ tests/ --select=E,F  # Errors only - must pass
	$(VENV_PY) -m ruff check src/ tests/ --exit-zero   # All rules - warnings allowed
	$(VENV_PY) -m mypy src/bcs/ --ignore-missing-imports || true  # Type checking - warnings allowed

# Format code
format: $(VENV_PY_FILE)
	$(VENV_PY) -m black src/ tests/
	$(VENV_PY) -m isort src/ tests/

# Check formatting (CI mode - no changes)
format-check: $(VENV_PY_FILE)
	$(VENV_PY) -m black --check src/ tests/
	$(VENV_PY) -m isort --check src/ tests/

# Build package
build: $(VENV_PY_FILE)
	$(VENV_PY) -m build

# Clean build artifacts
clean:
	rm -rf dist/ build/ *.egg-info
	rm -rf .pytest_cache .ruff_cache .mypy_cache
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

# Publish to PyPI
publish: build
	$(VENV_PY) -m twine upload dist/*

# Type check only
typecheck: $(VENV_PY_FILE)
	$(VENV_PY) -m mypy src/bcs/

# Development install
dev-install: deps

# Install required tools (Python, pip)
install-tools:
	@echo "=== Python SDK Tools Installation ==="
	@echo "Required: python3 (3.9+), pip"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install python@3.11"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install python3 python3-pip python3-venv"
	@echo ""
	@echo "Fedora:"
	@echo "  sudo dnf install python3 python3-pip"
	@echo ""
	@echo "After installation, run 'make deps' to install Python packages (black, ruff, pytest, etc.)"
	@echo ""
	@echo "Checking current installation..."
	@which python3 && python3 --version || echo "python3 not found"
