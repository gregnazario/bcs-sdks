#!/usr/bin/env python3
"""
BCS Benchmark Orchestrator

Runs correctness tests and performance benchmarks across all language SDKs,
comparing results to the reference Rust implementation.
"""

import argparse
import json
import os
import platform
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional

# Import from existing orchestrator
from orchestrator import (
    LANGUAGES,
    E2E_DIR,
    ROOT_DIR,
    SDKS_DIR,
    RUNNERS_DIR,
    TEST_DATA_DIR,
    run_command,
    generate_reference_vectors,
    run_language_tests,
    LanguageResult,
)


@dataclass
class BenchmarkResult:
    """Result of a single benchmark scenario."""
    name: str
    scenario_type: str
    iterations: int
    serialize_avg_ns: float
    serialize_min_ns: float
    serialize_max_ns: float
    serialize_p50_ns: float
    serialize_p95_ns: float
    deserialize_avg_ns: float
    deserialize_min_ns: float
    deserialize_max_ns: float
    deserialize_p50_ns: float
    deserialize_p95_ns: float
    throughput_serialize_ops_sec: float
    throughput_deserialize_ops_sec: float
    error: Optional[str] = None


@dataclass
class LanguageBenchmark:
    """Benchmark results for a single language."""
    language: str
    benchmarks: list[BenchmarkResult] = field(default_factory=list)
    total_time_ms: float = 0.0
    error: Optional[str] = None


@dataclass
class FullResults:
    """Complete results including correctness and benchmarks."""
    timestamp: str
    commit_hash: str
    machine_info: dict
    correctness: list[dict]
    benchmarks: list[dict]
    summary: dict


def get_machine_info() -> dict:
    """Get machine information for reproducibility."""
    return {
        "platform": platform.system(),
        "platform_release": platform.release(),
        "platform_version": platform.version(),
        "architecture": platform.machine(),
        "processor": platform.processor(),
        "python_version": platform.python_version(),
        "cpu_count": os.cpu_count(),
    }


def get_commit_hash() -> str:
    """Get current git commit hash."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            cwd=ROOT_DIR,
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        return "unknown"


def load_benchmark_spec() -> dict:
    """Load the benchmark specification."""
    spec_path = E2E_DIR / "benchmark-spec.json"
    with open(spec_path) as f:
        return json.load(f)


def get_benchmark_runner_command(language: str) -> tuple[list[str], Optional[Path]]:
    """Get the command to run the benchmark runner for a language."""
    runner_dir = RUNNERS_DIR
    sdk_dir = SDKS_DIR / language

    if language == "python":
        return ["python3", str(runner_dir / "python_runner.py"), "--benchmark"], None
    elif language == "typescript":
        return ["bun", "run", str(runner_dir / "typescript_runner.ts"), "--benchmark"], sdk_dir
    elif language == "go":
        return ["go", "run", str(runner_dir / "go_runner.go"), "--benchmark"], sdk_dir
    elif language == "rust":
        import shutil
        rust_runner_dir = runner_dir / "rust_runner"
        rust_binary = rust_runner_dir / "target" / "release" / "rust_runner"
        if rust_runner_dir.exists() and shutil.which("cargo"):
            result = subprocess.run(
                ["cargo", "build", "--release", "-q"],
                cwd=str(rust_runner_dir),
                capture_output=True
            )
            if result.returncode == 0 and rust_binary.exists():
                return [str(rust_binary), "--benchmark"], None
        return [], None
    elif language == "elixir":
        return ["elixir", str(runner_dir / "elixir_runner.exs"), "--benchmark"], sdk_dir
    elif language == "ruby":
        return ["ruby", str(runner_dir / "ruby_runner.rb"), "--benchmark"], sdk_dir
    elif language == "swift":
        return ["swift", str(runner_dir / "swift_runner.swift"), "--benchmark"], None
    elif language == "kotlin":
        import shutil
        kt_runner_dir = runner_dir / "kotlin_runner"
        if kt_runner_dir.exists() and shutil.which("gradle"):
            # Use Gradle to run the Kotlin runner
            return ["gradle", "-q", "--console=plain", "run", "--args=--benchmark"], kt_runner_dir
        return [], None
    elif language == "csharp":
        csharp_dir = runner_dir / "CSharpRunner"
        import shutil
        if csharp_dir.exists() and shutil.which("dotnet"):
            result = subprocess.run(
                ["dotnet", "build", "-c", "Release", "-o", str(csharp_dir / "bin"), "-v", "q"],
                cwd=str(csharp_dir),
                capture_output=True
            )
            if result.returncode == 0:
                return ["dotnet", str(csharp_dir / "bin" / "CSharpRunner.dll"), "--benchmark"], None
        return [], None
    elif language == "cpp":
        cpp_runner = runner_dir / "cpp_runner"
        cpp_source = runner_dir / "cpp_runner.cpp"
        if not cpp_runner.exists() or cpp_source.stat().st_mtime > cpp_runner.stat().st_mtime:
            subprocess.run(["g++", "-std=c++17", "-O2", "-o", str(cpp_runner), str(cpp_source)], check=True)
        return [str(cpp_runner), "--benchmark"], None
    elif language == "c":
        c_runner = runner_dir / "c_runner"
        c_source = runner_dir / "c_runner.c"
        if not c_runner.exists() or c_source.stat().st_mtime > c_runner.stat().st_mtime:
            subprocess.run(["gcc", "-std=c99", "-O2", "-o", str(c_runner), str(c_source)], check=True)
        return [str(c_runner), "--benchmark"], None
    elif language == "zig":
        return ["zig", "run", str(runner_dir / "zig_runner.zig"), "--", "--benchmark"], None
    elif language == "dart":
        return ["dart", "run", str(runner_dir / "dart_runner.dart"), "--benchmark"], None
    elif language == "java":
        import shutil
        java_runner_dir = runner_dir / "java_runner"
        if java_runner_dir.exists() and shutil.which("gradle"):
            # Use Gradle to run the Java runner
            return ["gradle", "-q", "--console=plain", "run", "--args=--benchmark"], java_runner_dir
        return [], None
    else:
        return [], None


def run_language_benchmark(language: str, spec: dict) -> LanguageBenchmark:
    """Run benchmarks for a single language."""
    cmd, cwd = get_benchmark_runner_command(language)

    if not cmd:
        return LanguageBenchmark(
            language=language,
            error=f"No benchmark runner configured for {language}",
        )

    # Prepare benchmark input
    input_data = json.dumps(spec)

    start_time = time.time()
    code, stdout, stderr = run_command(cmd, input_data=input_data, cwd=cwd)
    total_time = (time.time() - start_time) * 1000

    if code != 0:
        return LanguageBenchmark(
            language=language,
            error=f"Benchmark runner failed: {stderr[:500]}",
            total_time_ms=total_time,
        )

    try:
        output = json.loads(stdout)
    except json.JSONDecodeError as e:
        return LanguageBenchmark(
            language=language,
            error=f"Invalid JSON output: {e}",
            total_time_ms=total_time,
        )

    # Parse benchmark results
    benchmarks = []
    for result in output.get("benchmarks", []):
        benchmarks.append(BenchmarkResult(
            name=result["name"],
            scenario_type=result.get("type", "unknown"),
            iterations=result.get("iterations", 0),
            serialize_avg_ns=result.get("serialize_avg_ns", 0),
            serialize_min_ns=result.get("serialize_min_ns", 0),
            serialize_max_ns=result.get("serialize_max_ns", 0),
            serialize_p50_ns=result.get("serialize_p50_ns", 0),
            serialize_p95_ns=result.get("serialize_p95_ns", 0),
            deserialize_avg_ns=result.get("deserialize_avg_ns", 0),
            deserialize_min_ns=result.get("deserialize_min_ns", 0),
            deserialize_max_ns=result.get("deserialize_max_ns", 0),
            deserialize_p50_ns=result.get("deserialize_p50_ns", 0),
            deserialize_p95_ns=result.get("deserialize_p95_ns", 0),
            throughput_serialize_ops_sec=result.get("throughput_serialize_ops_sec", 0),
            throughput_deserialize_ops_sec=result.get("throughput_deserialize_ops_sec", 0),
            error=result.get("error"),
        ))

    return LanguageBenchmark(
        language=language,
        benchmarks=benchmarks,
        total_time_ms=total_time,
    )


def compute_summary(correctness_results: list[LanguageResult], benchmark_results: list[LanguageBenchmark]) -> dict:
    """Compute summary statistics across all languages."""
    summary = {
        "languages_tested": len(correctness_results),
        "total_correctness_tests": 0,
        "total_passed": 0,
        "total_failed": 0,
        "total_skipped": 0,
        "benchmark_scenarios": 0,
        "languages_with_benchmarks": 0,
        "per_language": {},
    }

    # Correctness summary
    for result in correctness_results:
        summary["total_passed"] += result.passed
        summary["total_failed"] += result.failed
        summary["total_skipped"] += result.skipped
        summary["total_correctness_tests"] += result.passed + result.failed + result.skipped

        summary["per_language"][result.language] = {
            "correctness_passed": result.passed,
            "correctness_failed": result.failed,
            "correctness_skipped": result.skipped,
            "correctness_status": "PASS" if result.failed == 0 else "FAIL",
        }

    # Benchmark summary - find Rust baseline
    rust_benchmarks = {}
    for bench_result in benchmark_results:
        if bench_result.language == "rust" and not bench_result.error:
            for b in bench_result.benchmarks:
                rust_benchmarks[b.name] = b
            break

    for bench_result in benchmark_results:
        if bench_result.error:
            if bench_result.language in summary["per_language"]:
                summary["per_language"][bench_result.language]["benchmark_error"] = bench_result.error
            continue

        summary["languages_with_benchmarks"] += 1
        if bench_result.benchmarks:
            summary["benchmark_scenarios"] = max(summary["benchmark_scenarios"], len(bench_result.benchmarks))

        lang_summary = summary["per_language"].get(bench_result.language, {})

        # Compute average serialize/deserialize times across all scenarios
        if bench_result.benchmarks:
            avg_serialize = sum(b.serialize_avg_ns for b in bench_result.benchmarks) / len(bench_result.benchmarks)
            avg_deserialize = sum(b.deserialize_avg_ns for b in bench_result.benchmarks) / len(bench_result.benchmarks)

            lang_summary["avg_serialize_ns"] = avg_serialize
            lang_summary["avg_deserialize_ns"] = avg_deserialize

            # Compute relative to Rust
            if rust_benchmarks and bench_result.language != "rust":
                rust_avg_ser = sum(rust_benchmarks[b.name].serialize_avg_ns for b in bench_result.benchmarks if b.name in rust_benchmarks) / len(bench_result.benchmarks) if bench_result.benchmarks else 1
                rust_avg_de = sum(rust_benchmarks[b.name].deserialize_avg_ns for b in bench_result.benchmarks if b.name in rust_benchmarks) / len(bench_result.benchmarks) if bench_result.benchmarks else 1

                if rust_avg_ser > 0:
                    lang_summary["vs_rust_serialize"] = round(avg_serialize / rust_avg_ser, 2)
                if rust_avg_de > 0:
                    lang_summary["vs_rust_deserialize"] = round(avg_deserialize / rust_avg_de, 2)
            elif bench_result.language == "rust":
                lang_summary["vs_rust_serialize"] = 1.0
                lang_summary["vs_rust_deserialize"] = 1.0

        summary["per_language"][bench_result.language] = lang_summary

    return summary


def run_all_tests(languages: list[str], run_benchmarks: bool = True, verbose: bool = False) -> FullResults:
    """Run all correctness tests and optionally benchmarks."""
    print("Generating reference test vectors...")
    vectors = generate_reference_vectors()

    # Ensure test-data directory exists
    TEST_DATA_DIR.mkdir(exist_ok=True)

    # Save vectors
    with open(TEST_DATA_DIR / "reference_vectors.json", "w") as f:
        json.dump(vectors, f, indent=2)

    # Run correctness tests
    print("\n" + "=" * 70)
    print("Running Correctness Tests")
    print("=" * 70)

    correctness_results = []
    for lang in languages:
        if not (SDKS_DIR / lang).exists():
            print(f"Skipping {lang}: SDK not found")
            continue

        print(f"Testing {lang}...")
        result = run_language_tests(lang, vectors)
        correctness_results.append(result)

        status = "✓" if result.failed == 0 and result.skipped == 0 else "✗"
        print(f"  {status} passed: {result.passed} | failed: {result.failed} | skipped: {result.skipped}")

    # Run benchmarks if requested
    benchmark_results = []
    if run_benchmarks:
        print("\n" + "=" * 70)
        print("Running Benchmarks")
        print("=" * 70)

        spec = load_benchmark_spec()

        for lang in languages:
            if not (SDKS_DIR / lang).exists():
                continue

            print(f"Benchmarking {lang}...")
            result = run_language_benchmark(lang, spec)
            benchmark_results.append(result)

            if result.error:
                print(f"  ✗ Error: {result.error[:100]}")
            else:
                print(f"  ✓ {len(result.benchmarks)} scenarios completed in {result.total_time_ms:.0f}ms")

    # Compute summary
    summary = compute_summary(correctness_results, benchmark_results)

    # Build full results
    return FullResults(
        timestamp=datetime.now().isoformat(),
        commit_hash=get_commit_hash(),
        machine_info=get_machine_info(),
        correctness=[
            {
                "language": r.language,
                "passed": r.passed,
                "failed": r.failed,
                "skipped": r.skipped,
                "errors": r.errors,
            }
            for r in correctness_results
        ],
        benchmarks=[
            {
                "language": r.language,
                "benchmarks": [asdict(b) for b in r.benchmarks],
                "total_time_ms": r.total_time_ms,
                "error": r.error,
            }
            for r in benchmark_results
        ],
        summary=summary,
    )


def save_results(results: FullResults, output_path: Path):
    """Save results to JSON file."""
    with open(output_path, "w") as f:
        json.dump(asdict(results), f, indent=2)
    print(f"\nResults saved to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="BCS Benchmark Orchestrator")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("-l", "--language", help="Test specific language only")
    parser.add_argument("--correctness-only", action="store_true", help="Run only correctness tests")
    parser.add_argument("--benchmark-only", action="store_true", help="Run only benchmarks")
    parser.add_argument("-o", "--output", default="benchmark_results.json", help="Output JSON file")
    args = parser.parse_args()

    languages = [args.language] if args.language else LANGUAGES

    run_benchmarks = not args.correctness_only
    if args.benchmark_only:
        run_benchmarks = True

    results = run_all_tests(
        languages=languages,
        run_benchmarks=run_benchmarks,
        verbose=args.verbose,
    )

    # Save results
    output_path = TEST_DATA_DIR / args.output
    TEST_DATA_DIR.mkdir(exist_ok=True)
    save_results(results, output_path)

    # Print summary
    print("\n" + "=" * 70)
    print("Summary")
    print("=" * 70)
    print(f"Languages tested: {results.summary['languages_tested']}")
    print(f"Total tests: {results.summary['total_correctness_tests']}")
    print(f"Passed: {results.summary['total_passed']}")
    print(f"Failed: {results.summary['total_failed']}")
    print(f"Skipped: {results.summary['total_skipped']}")

    if run_benchmarks:
        print(f"Benchmark scenarios: {results.summary['benchmark_scenarios']}")
        print(f"Languages with benchmarks: {results.summary['languages_with_benchmarks']}")

    # Exit with error if any tests failed
    sys.exit(0 if results.summary['total_failed'] == 0 else 1)


if __name__ == "__main__":
    main()
