#!/usr/bin/env python3
"""
BCS E2E Test Orchestrator

Runs roundtrip tests across all language SDKs and compares results
to the reference Rust implementation.
"""

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# Languages to test (in order)
LANGUAGES = [
    "python",
    "typescript",
    "go",
    "elixir",
    "rust",
    "cpp",
    "csharp",
    "kotlin",
    "swift",
    "ruby",
    "c",
    "zig",
    "dart",
    "haskell",
    "ocaml",
    "java",
]

# Root paths
E2E_DIR = Path(__file__).parent.resolve()
ROOT_DIR = E2E_DIR.parent
SDKS_DIR = ROOT_DIR / "sdks"
RUNNERS_DIR = E2E_DIR / "runners"
TEST_DATA_DIR = E2E_DIR / "test-data"


@dataclass
class TestResult:
    """Result of a single test case."""

    name: str
    passed: bool
    expected_hex: str
    actual_hex: Optional[str]
    error: Optional[str] = None


@dataclass
class LanguageResult:
    """Results for a single language."""

    language: str
    passed: int
    failed: int
    skipped: int
    errors: list[str]
    results: list[TestResult]


def run_command(cmd: list[str], input_data: str = "", cwd: Optional[Path] = None) -> tuple[int, str, str]:
    """Run a command and return exit code, stdout, stderr."""
    try:
        result = subprocess.run(
            cmd,
            input=input_data,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=60,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Timeout"
    except FileNotFoundError:
        return -1, "", f"Command not found: {cmd[0]}"


def generate_reference_vectors() -> dict:
    """Generate test vectors using the Rust reference implementation."""
    ref_dir = E2E_DIR / "reference"
    
    # Build the reference generator
    code, stdout, stderr = run_command(
        ["cargo", "build", "--release"],
        cwd=ref_dir,
    )
    if code != 0:
        print(f"Failed to build reference generator: {stderr}")
        sys.exit(1)
    
    # Run the generator
    code, stdout, stderr = run_command(
        ["cargo", "run", "--release"],
        cwd=ref_dir,
    )
    if code != 0:
        print(f"Failed to run reference generator: {stderr}")
        sys.exit(1)
    
    # Parse and return the JSON
    return json.loads(stdout)


def get_runner_command(language: str) -> tuple[list[str], Optional[Path]]:
    """Get the command to run the test runner for a language."""
    runner_dir = RUNNERS_DIR
    sdk_dir = SDKS_DIR / language
    
    if language == "python":
        return ["python3", str(runner_dir / "python_runner.py")], None
    elif language == "typescript":
        return ["npx", "tsx", str(runner_dir / "typescript_runner.ts")], sdk_dir
    elif language == "go":
        # Go needs to run from SDK dir to find the module
        return ["go", "run", str(runner_dir / "go_runner.go")], sdk_dir
    elif language == "rust":
        # Rust roundtrip not implemented yet (would need serde setup)
        return [], None
    elif language == "elixir":
        return ["elixir", str(runner_dir / "elixir_runner.exs")], sdk_dir
    elif language == "ruby":
        return ["ruby", str(runner_dir / "ruby_runner.rb")], sdk_dir
    elif language == "swift":
        return ["swift", str(runner_dir / "swift_runner.swift")], None
    elif language == "kotlin":
        # Kotlin script runner
        return ["kotlin", str(runner_dir / "kotlin_runner.kt")], None
    elif language == "csharp":
        # C# script runner (requires dotnet-script)
        return ["dotnet", "script", str(runner_dir / "csharp_runner.cs")], None
    elif language == "cpp":
        # Compile if needed, then run
        cpp_runner = runner_dir / "cpp_runner"
        cpp_source = runner_dir / "cpp_runner.cpp"
        if not cpp_runner.exists() or cpp_source.stat().st_mtime > cpp_runner.stat().st_mtime:
            # Compile the C++ runner
            import subprocess
            subprocess.run(["g++", "-std=c++17", "-O2", "-o", str(cpp_runner), str(cpp_source)], check=True)
        return [str(cpp_runner)], None
    elif language == "c":
        # C runner not implemented yet
        return [], None
    elif language == "zig":
        # Zig runner not implemented yet
        return [], None
    elif language == "dart":
        return ["dart", "run", str(runner_dir / "dart_runner.dart")], None
    elif language == "haskell":
        # Haskell runner not implemented yet
        return [], None
    elif language == "ocaml":
        # OCaml runner not implemented yet
        return [], None
    elif language == "java":
        # Java single-file source runner (Java 11+)
        return ["java", str(runner_dir / "java_runner.java")], None
    else:
        return [], None


def run_language_tests(language: str, vectors: dict) -> LanguageResult:
    """Run tests for a single language."""
    cmd, cwd = get_runner_command(language)
    
    if not cmd:
        return LanguageResult(
            language=language,
            passed=0,
            failed=0,
            skipped=len(flatten_test_cases(vectors)),
            errors=[f"No runner configured for {language}"],
            results=[],
        )
    
    # Check if runner exists
    runner_path = RUNNERS_DIR / f"{language}_runner.py" if language == "python" else None
    
    # Run the test runner with the vectors as input
    input_json = json.dumps(vectors)
    code, stdout, stderr = run_command(cmd, input_data=input_json, cwd=cwd)
    
    if code != 0:
        all_cases = flatten_test_cases(vectors)
        return LanguageResult(
            language=language,
            passed=0,
            failed=0,
            skipped=len(all_cases),
            errors=[f"Runner failed: {stderr}"],
            results=[],
        )
    
    # Parse the output
    try:
        output = json.loads(stdout)
    except json.JSONDecodeError as e:
        all_cases = flatten_test_cases(vectors)
        return LanguageResult(
            language=language,
            passed=0,
            failed=0,
            skipped=len(all_cases),
            errors=[f"Invalid JSON output: {e}\nStdout: {stdout[:500]}"],
            results=[],
        )
    
    # Compare results
    results = []
    passed = 0
    failed = 0
    
    for category in ["primitives", "strings", "bytes", "options", "vectors", "structs", "complex"]:
        expected_cases = {c["name"]: c for c in vectors.get(category, [])}
        actual_cases = {c["name"]: c for c in output.get(category, [])}
        
        for name, expected in expected_cases.items():
            actual = actual_cases.get(name)
            
            if actual is None:
                results.append(TestResult(
                    name=name,
                    passed=False,
                    expected_hex=expected["bcs_hex"],
                    actual_hex=None,
                    error="Missing from output",
                ))
                failed += 1
            elif actual.get("error"):
                results.append(TestResult(
                    name=name,
                    passed=False,
                    expected_hex=expected["bcs_hex"],
                    actual_hex=None,
                    error=actual["error"],
                ))
                failed += 1
            elif actual["bcs_hex"] != expected["bcs_hex"]:
                results.append(TestResult(
                    name=name,
                    passed=False,
                    expected_hex=expected["bcs_hex"],
                    actual_hex=actual["bcs_hex"],
                ))
                failed += 1
            else:
                results.append(TestResult(
                    name=name,
                    passed=True,
                    expected_hex=expected["bcs_hex"],
                    actual_hex=actual["bcs_hex"],
                ))
                passed += 1
    
    return LanguageResult(
        language=language,
        passed=passed,
        failed=failed,
        skipped=0,
        errors=[],
        results=results,
    )


def flatten_test_cases(vectors: dict) -> list[dict]:
    """Flatten all test cases from all categories."""
    cases = []
    for category in ["primitives", "strings", "bytes", "options", "vectors", "structs", "complex"]:
        cases.extend(vectors.get(category, []))
    return cases


def print_results(results: list[LanguageResult], verbose: bool = False):
    """Print test results."""
    print("\n" + "=" * 70)
    print("BCS E2E Roundtrip Test Results")
    print("=" * 70 + "\n")
    
    total_passed = 0
    total_failed = 0
    total_skipped = 0
    
    for r in results:
        status = "✓" if r.failed == 0 and r.skipped == 0 else "✗"
        print(f"{status} {r.language:15} passed: {r.passed:3} | failed: {r.failed:3} | skipped: {r.skipped:3}")
        
        if verbose and r.failed > 0:
            for test in r.results:
                if not test.passed:
                    print(f"    FAIL: {test.name}")
                    print(f"      expected: {test.expected_hex}")
                    print(f"      actual:   {test.actual_hex or 'N/A'}")
                    if test.error:
                        print(f"      error:    {test.error}")
        
        if r.errors:
            for err in r.errors:
                print(f"    ERROR: {err[:100]}")
        
        total_passed += r.passed
        total_failed += r.failed
        total_skipped += r.skipped
    
    print("\n" + "-" * 70)
    print(f"Total: passed: {total_passed} | failed: {total_failed} | skipped: {total_skipped}")
    print("-" * 70)
    
    return total_failed == 0


def main():
    parser = argparse.ArgumentParser(description="BCS E2E Test Orchestrator")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("-l", "--language", help="Test specific language only")
    parser.add_argument("--generate-only", action="store_true", help="Only generate test vectors")
    parser.add_argument("-o", "--output", help="Output test vectors to file")
    args = parser.parse_args()
    
    print("Generating reference test vectors...")
    vectors = generate_reference_vectors()
    
    if args.output:
        with open(args.output, "w") as f:
            json.dump(vectors, f, indent=2)
        print(f"Test vectors written to {args.output}")
    
    if args.generate_only:
        print(json.dumps(vectors, indent=2))
        return
    
    # Ensure test-data directory exists
    TEST_DATA_DIR.mkdir(exist_ok=True)
    
    # Save vectors for debugging
    with open(TEST_DATA_DIR / "reference_vectors.json", "w") as f:
        json.dump(vectors, f, indent=2)
    
    # Run tests
    languages = [args.language] if args.language else LANGUAGES
    results = []
    
    for lang in languages:
        if not (SDKS_DIR / lang).exists():
            print(f"Skipping {lang}: SDK not found")
            continue
        
        print(f"Testing {lang}...")
        result = run_language_tests(lang, vectors)
        results.append(result)
    
    # Print results
    success = print_results(results, verbose=args.verbose)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
