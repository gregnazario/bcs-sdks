# BCS C# SDK Makefile

.PHONY: all test lint format format-check build clean publish deps pack install-tools ci

# Path to shared test vectors
TEST_VECTORS := ../../test-vectors

# Default target
all: format-check lint test

# Restore dependencies
deps:
	dotnet restore

# Run tests
test: deps
	TEST_VECTORS=$(TEST_VECTORS) dotnet test --no-restore

# Run tests with coverage
test-cov: deps
	TEST_VECTORS=$(TEST_VECTORS) dotnet test --no-restore --collect:"XPlat Code Coverage"

# Lint (using dotnet format as analyzer)
lint: deps
	dotnet format --verify-no-changes --severity warn

# Format code
format: deps
	dotnet format

# Check formatting (CI mode - no changes)
format-check: deps
	dotnet format --verify-no-changes

# Build
build: deps
	dotnet build --no-restore -c Release

# Clean build artifacts
clean:
	dotnet clean
	rm -rf */bin */obj

# Pack NuGet package
pack: build
	dotnet pack Bcs/Bcs.csproj -c Release --no-build -o ./nupkg

# Publish to NuGet
publish: pack
	dotnet nuget push ./nupkg/*.nupkg --source https://api.nuget.org/v3/index.json --api-key $(NUGET_API_KEY)

# Run all checks (for CI)
ci: deps format-check lint test

# Install required tools (.NET SDK)
install-tools:
	@echo "=== C# SDK Tools Installation ==="
	@echo "Required: dotnet SDK (8.0+)"
	@echo ""
	@echo "macOS (Homebrew):"
	@echo "  brew install --cask dotnet-sdk"
	@echo ""
	@echo "Ubuntu/Debian:"
	@echo "  wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb"
	@echo "  sudo dpkg -i packages-microsoft-prod.deb"
	@echo "  sudo apt update && sudo apt install dotnet-sdk-8.0"
	@echo ""
	@echo "Official installer:"
	@echo "  https://dotnet.microsoft.com/download"
	@echo ""
	@echo "After installation, run 'make deps' to restore NuGet packages"
	@echo ""
	@echo "Checking current installation..."
	@which dotnet && dotnet --version || echo "dotnet not found"
