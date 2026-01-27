# BCS C++ SDK Makefile

.PHONY: all test lint format format-check build clean deps test-vectors install-tools docs publish

# Compiler settings
CXX := clang++
CXXFLAGS := -std=c++17 -Wall -Wextra -Wpedantic -Werror
CXXFLAGS += -I include -I tests

# Debug/Release modes
DEBUG_FLAGS := -g -O0 -DDEBUG
RELEASE_FLAGS := -O3 -DNDEBUG

# Paths
TEST_VECTORS := ../../test-vectors
BUILD_DIR := build
TEST_BIN := $(BUILD_DIR)/test_bcs

# Source files
TEST_SOURCES := tests/test_bcs.cpp

# Default target
all: format-check lint test

# Build tests
$(TEST_BIN): $(TEST_SOURCES)
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(DEBUG_FLAGS) -o $@ $(TEST_SOURCES)

# Run tests
test: $(TEST_BIN)
	./$(TEST_BIN)

# Run tests with test vectors enabled
test-vectors: $(TEST_BIN)
	./$(TEST_BIN) --test-case="Test vectors from JSON"

# Lint with clang-tidy
lint:
	@echo "Running clang-tidy..."
	@find include -name "*.hpp" -exec clang-tidy {} -- $(CXXFLAGS) \; 2>/dev/null || true

# Format code with clang-format
format:
	@echo "Formatting code..."
	@find include -name "*.hpp" -exec clang-format -i {} \;
	@find tests -name "*.cpp" ! -name "doctest.h" ! -name "json.hpp" -exec clang-format -i {} \;

# Check formatting (CI mode)
format-check:
	@echo "Checking code formatting..."
	@! find include -name "*.hpp" -exec clang-format --dry-run --Werror {} \; 2>&1 | grep -q "error:" || \
		(echo "Format check failed" && exit 1)

# Build/verify compilation (header-only library)
build:
	@mkdir -p $(BUILD_DIR)
	@echo '#include <bcs/bcs.hpp>' | $(CXX) $(CXXFLAGS) $(RELEASE_FLAGS) -c -o $(BUILD_DIR)/verify.o -x c++ -
	@echo "Header-only library compiles successfully"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

# Install dependencies (header-only library, minimal deps)
deps:
	@echo "C++ SDK is header-only, no runtime dependencies needed."
	@echo "Test dependencies (doctest, nlohmann/json) are included in tests/"

# Install system dependencies (for CI)
install-tools:
	@echo "Ensure clang++, clang-format, and clang-tidy are installed"
	@which clang++ || echo "Install clang: brew install llvm (macOS) or apt install clang (Linux)"
	@which clang-format || echo "Install clang-format"
	@which clang-tidy || echo "Install clang-tidy"

# Generate documentation (requires doxygen)
docs:
	@which doxygen > /dev/null || (echo "Install doxygen for documentation" && exit 1)
	doxygen Doxyfile 2>/dev/null || echo "Create Doxyfile for documentation generation"

# Publish (header-only library - typically just copy headers)
publish:
	@echo "C++ SDK is header-only. To install:"
	@echo "  cp -r include/bcs /usr/local/include/"
	@echo "Or use CMake FetchContent / add_subdirectory"

# Run all checks (for CI)
ci: deps format-check lint test
