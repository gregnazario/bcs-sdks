# BCS C SDK Makefile

.PHONY: all test lint format format-check build clean install deps docs debug sanitize install-tools ci

# Compiler settings
CC ?= cc
CFLAGS ?= -Wall -Wextra -Wpedantic -std=c99 -O2
CFLAGS += -I include

# Debug flags
DEBUG_CFLAGS = -g -O0 -DDEBUG

# Directories
SRC_DIR = src
INCLUDE_DIR = include
TEST_DIR = tests
BUILD_DIR = build

# Source files
SRCS = $(SRC_DIR)/bcs.c
OBJS = $(BUILD_DIR)/bcs.o
TEST_SRCS = $(TEST_DIR)/test_bcs.c
TEST_BIN = $(BUILD_DIR)/test_bcs

# Library outputs
STATIC_LIB = $(BUILD_DIR)/libbcs.a

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Build library
build: $(BUILD_DIR) $(STATIC_LIB)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/bcs.o: $(SRCS) $(INCLUDE_DIR)/bcs/bcs.h
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $(SRCS) -o $@

$(STATIC_LIB): $(OBJS)
	@mkdir -p $(BUILD_DIR)
	ar rcs $@ $^

# Build tests
$(TEST_BIN): $(TEST_SRCS) $(STATIC_LIB)
	$(CC) $(CFLAGS) $(DEBUG_CFLAGS) $(TEST_SRCS) -L$(BUILD_DIR) -lbcs -o $@

# Run tests
test: $(TEST_BIN)
	./$(TEST_BIN)

# Lint with clang-tidy (if available)
lint:
	@if command -v clang-tidy >/dev/null 2>&1; then \
		clang-tidy $(SRCS) $(TEST_SRCS) -- $(CFLAGS); \
	else \
		echo "clang-tidy not found, skipping lint"; \
	fi

# Format code with clang-format
format:
	@if command -v clang-format >/dev/null 2>&1; then \
		clang-format -i $(SRCS) $(TEST_SRCS) $(INCLUDE_DIR)/bcs/*.h; \
	else \
		echo "clang-format not found, skipping format"; \
	fi

# Check formatting (CI mode - no changes)
format-check:
	@if command -v clang-format >/dev/null 2>&1; then \
		clang-format --dry-run --Werror $(SRCS) $(TEST_SRCS) $(INCLUDE_DIR)/bcs/*.h; \
	else \
		echo "clang-format not found, skipping format-check"; \
	fi

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

# Install headers and library
install: build
	install -d $(DESTDIR)$(PREFIX)/include/bcs
	install -m 644 $(INCLUDE_DIR)/bcs/bcs.h $(DESTDIR)$(PREFIX)/include/bcs/
	install -d $(DESTDIR)$(PREFIX)/lib
	install -m 644 $(STATIC_LIB) $(DESTDIR)$(PREFIX)/lib/

# Install dependencies (none for C)
deps:
	@echo "No dependencies to install for C SDK"

# Generate documentation (with doxygen if available)
docs:
	@if command -v doxygen >/dev/null 2>&1; then \
		doxygen Doxyfile 2>/dev/null || echo "No Doxyfile found"; \
	else \
		echo "doxygen not found, skipping docs"; \
	fi

# Build with debug flags
debug: CFLAGS += $(DEBUG_CFLAGS)
debug: clean build

# Build with sanitizers
sanitize: CFLAGS += -fsanitize=address,undefined
sanitize: clean $(TEST_BIN)
	./$(TEST_BIN)

# Run all checks (for CI)
ci: deps build format-check lint test

# Install required tools (C compiler, clang-format, clang-tidy)
install-tools:
	@echo "=== C SDK Tools Installation ==="
	@echo "Required: cc/gcc/clang, clang-format, clang-tidy"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  xcode-select --install  # Install command line tools (includes clang)"
	@echo "  brew install llvm  # For clang-format and clang-tidy"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  sudo apt update && sudo apt install build-essential clang clang-format clang-tidy"
	@echo ""
	@echo "Fedora:"
	@echo "  sudo dnf install gcc clang clang-tools-extra"
	@echo ""
	@echo "After installation, the SDK has no additional dependencies"
	@echo ""
	@echo "Checking current installation..."
	@which cc && cc --version | head -1 || which gcc && gcc --version | head -1 || which clang && clang --version | head -1 || echo "C compiler not found"
	@which clang-format && clang-format --version || echo "clang-format not found"
	@which clang-tidy && clang-tidy --version | head -1 || echo "clang-tidy not found"
