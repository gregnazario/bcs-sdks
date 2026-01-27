#!/usr/bin/env python3
"""
BCS Benchmark Report Generator

Reads benchmark results JSON and generates a markdown report with ASCII charts.
"""

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Optional


@dataclass
class LanguageStats:
    """Statistics for a single language."""
    language: str
    correctness_passed: int
    correctness_failed: int
    correctness_skipped: int
    avg_serialize_ns: float
    avg_deserialize_ns: float
    vs_rust_serialize: float
    vs_rust_deserialize: float
    benchmark_error: Optional[str] = None


def format_time(ns: float) -> str:
    """Format nanoseconds into a human-readable string."""
    if ns >= 1_000_000_000:
        return f"{ns / 1_000_000_000:.2f} s"
    elif ns >= 1_000_000:
        return f"{ns / 1_000_000:.2f} ms"
    elif ns >= 1_000:
        return f"{ns / 1_000:.2f} us"
    else:
        return f"{ns:.0f} ns"


def format_throughput(ops_sec: float) -> str:
    """Format operations per second."""
    if ops_sec >= 1_000_000:
        return f"{ops_sec / 1_000_000:.2f}M ops/s"
    elif ops_sec >= 1_000:
        return f"{ops_sec / 1_000:.2f}K ops/s"
    else:
        return f"{ops_sec:.0f} ops/s"


def make_bar(value: float, max_value: float, width: int = 40) -> str:
    """Create an ASCII bar chart."""
    if max_value <= 0:
        return ""
    ratio = min(value / max_value, 1.0)
    filled = int(ratio * width)
    return "█" * filled + "░" * (width - filled)


def generate_summary_table(stats: list[LanguageStats]) -> str:
    """Generate the summary table."""
    lines = [
        "| Language | Correctness | Serialize | Deserialize | vs Rust (Ser) | vs Rust (De) |",
        "|----------|-------------|-----------|-------------|---------------|--------------|",
    ]
    
    for s in sorted(stats, key=lambda x: x.vs_rust_serialize if x.vs_rust_serialize > 0 else float('inf')):
        correctness = f"{s.correctness_passed}/{s.correctness_passed + s.correctness_failed}"
        if s.correctness_failed > 0:
            correctness += " FAIL"
        else:
            correctness += " PASS"
        
        if s.benchmark_error:
            ser = "N/A"
            de = "N/A"
            vs_ser = "N/A"
            vs_de = "N/A"
        else:
            ser = format_time(s.avg_serialize_ns)
            de = format_time(s.avg_deserialize_ns)
            if s.language == "rust":
                vs_ser = "baseline"
                vs_de = "baseline"
            else:
                vs_ser = f"{s.vs_rust_serialize:.1f}x" if s.vs_rust_serialize > 0 else "N/A"
                vs_de = f"{s.vs_rust_deserialize:.1f}x" if s.vs_rust_deserialize > 0 else "N/A"
        
        lines.append(f"| {s.language:8} | {correctness:11} | {ser:9} | {de:11} | {vs_ser:13} | {vs_de:12} |")
    
    return "\n".join(lines)


def generate_performance_chart(
    stats: list[LanguageStats],
    metric: str,
    title: str,
) -> str:
    """Generate an ASCII bar chart for a metric."""
    lines = [f"### {title}", "", "```"]
    
    if metric == "serialize":
        values = [(s.language, s.avg_serialize_ns) for s in stats if not s.benchmark_error and s.avg_serialize_ns > 0]
    else:
        values = [(s.language, s.avg_deserialize_ns) for s in stats if not s.benchmark_error and s.avg_deserialize_ns > 0]
    
    if not values:
        lines.append("No data available")
        lines.append("```")
        return "\n".join(lines)
    
    # Sort by value (fastest first)
    values.sort(key=lambda x: x[1])
    max_value = max(v for _, v in values) if values else 1
    
    for lang, value in values:
        bar = make_bar(value, max_value, 40)
        time_str = format_time(value)
        lines.append(f"{lang:12} |{bar}| {time_str}")
    
    lines.append("```")
    return "\n".join(lines)


def generate_detailed_benchmarks(results: dict) -> str:
    """Generate detailed benchmark results section."""
    lines = ["## Detailed Benchmark Results", ""]
    
    benchmarks_by_lang = {}
    for bench_result in results.get("benchmarks", []):
        lang = bench_result.get("language", "unknown")
        benchmarks_by_lang[lang] = bench_result.get("benchmarks", [])
    
    if not benchmarks_by_lang:
        return "No detailed benchmark data available.\n"
    
    # Get all benchmark names from the first language with data
    benchmark_names = []
    for benchmarks in benchmarks_by_lang.values():
        if benchmarks:
            benchmark_names = [b["name"] for b in benchmarks]
            break
    
    if not benchmark_names:
        return "No benchmark scenarios found.\n"
    
    # Create a table for each benchmark scenario
    for bench_name in benchmark_names[:10]:  # Limit to first 10 for readability
        lines.append(f"### {bench_name}")
        lines.append("")
        lines.append("| Language | Serialize (avg) | Deserialize (avg) | Ser Throughput | De Throughput |")
        lines.append("|----------|-----------------|-------------------|----------------|---------------|")
        
        for lang in sorted(benchmarks_by_lang.keys()):
            benchmarks = benchmarks_by_lang[lang]
            bench = next((b for b in benchmarks if b.get("name") == bench_name), None)
            
            if bench and not bench.get("error"):
                ser_avg = format_time(bench.get("serialize_avg_ns", 0))
                de_avg = format_time(bench.get("deserialize_avg_ns", 0))
                ser_tp = format_throughput(bench.get("throughput_serialize_ops_sec", 0))
                de_tp = format_throughput(bench.get("throughput_deserialize_ops_sec", 0))
                lines.append(f"| {lang:8} | {ser_avg:15} | {de_avg:17} | {ser_tp:14} | {de_tp:13} |")
            elif bench and bench.get("error"):
                lines.append(f"| {lang:8} | Error: {bench.get('error', 'unknown')[:30]:43} |")
            else:
                lines.append(f"| {lang:8} | N/A | N/A | N/A | N/A |")
        
        lines.append("")
    
    return "\n".join(lines)


def generate_correctness_details(results: dict) -> str:
    """Generate correctness test details section."""
    lines = ["## Correctness Test Details", ""]
    
    for result in results.get("correctness", []):
        lang = result.get("language", "unknown")
        passed = result.get("passed", 0)
        failed = result.get("failed", 0)
        skipped = result.get("skipped", 0)
        errors = result.get("errors", [])
        
        status = "PASS" if failed == 0 else "FAIL"
        lines.append(f"### {lang.capitalize()} - {status}")
        lines.append("")
        lines.append(f"- Passed: {passed}")
        lines.append(f"- Failed: {failed}")
        lines.append(f"- Skipped: {skipped}")
        
        if errors:
            lines.append("")
            lines.append("**Errors:**")
            for err in errors[:5]:  # Limit to first 5 errors
                lines.append(f"- {err[:100]}")
        
        lines.append("")
    
    return "\n".join(lines)


def generate_machine_info(results: dict) -> str:
    """Generate machine info section."""
    info = results.get("machine_info", {})
    if not info:
        return ""
    
    lines = [
        "## Test Environment",
        "",
        f"- **Platform**: {info.get('platform', 'N/A')} {info.get('platform_release', '')}",
        f"- **Architecture**: {info.get('architecture', 'N/A')}",
        f"- **Processor**: {info.get('processor', 'N/A')}",
        f"- **CPU Cores**: {info.get('cpu_count', 'N/A')}",
        f"- **Python Version**: {info.get('python_version', 'N/A')}",
        "",
    ]
    
    return "\n".join(lines)


def generate_report(results: dict) -> str:
    """Generate the full markdown report."""
    timestamp = results.get("timestamp", datetime.now().isoformat())
    commit = results.get("commit_hash", "unknown")
    summary = results.get("summary", {})
    
    # Build language stats
    stats = []
    for lang, lang_summary in summary.get("per_language", {}).items():
        stats.append(LanguageStats(
            language=lang,
            correctness_passed=lang_summary.get("correctness_passed", 0),
            correctness_failed=lang_summary.get("correctness_failed", 0),
            correctness_skipped=lang_summary.get("correctness_skipped", 0),
            avg_serialize_ns=lang_summary.get("avg_serialize_ns", 0),
            avg_deserialize_ns=lang_summary.get("avg_deserialize_ns", 0),
            vs_rust_serialize=lang_summary.get("vs_rust_serialize", 0),
            vs_rust_deserialize=lang_summary.get("vs_rust_deserialize", 0),
            benchmark_error=lang_summary.get("benchmark_error"),
        ))
    
    # Generate report sections
    sections = [
        "# BCS SDK Benchmark Report",
        "",
        f"**Generated**: {timestamp[:19].replace('T', ' ')}",
        f"**Commit**: {commit}",
        "",
        generate_machine_info(results),
        "## Summary",
        "",
        f"- **Languages Tested**: {summary.get('languages_tested', 0)}",
        f"- **Total Correctness Tests**: {summary.get('total_correctness_tests', 0)}",
        f"- **Tests Passed**: {summary.get('total_passed', 0)}",
        f"- **Tests Failed**: {summary.get('total_failed', 0)}",
        f"- **Benchmark Scenarios**: {summary.get('benchmark_scenarios', 0)}",
        "",
        "## Performance Comparison",
        "",
        generate_summary_table(stats),
        "",
        "## Performance Charts",
        "",
        generate_performance_chart(stats, "serialize", "Serialization Performance (lower is better)"),
        "",
        generate_performance_chart(stats, "deserialize", "Deserialization Performance (lower is better)"),
        "",
        generate_detailed_benchmarks(results),
        generate_correctness_details(results),
        "---",
        "",
        "*Report generated by BCS Benchmark Orchestrator*",
    ]
    
    return "\n".join(sections)


def main():
    parser = argparse.ArgumentParser(description="Generate BCS Benchmark Report")
    parser.add_argument(
        "-i", "--input",
        default="test-data/benchmark_results.json",
        help="Input JSON file with benchmark results",
    )
    parser.add_argument(
        "-o", "--output",
        default="../BENCHMARK_REPORT.md",
        help="Output markdown file",
    )
    args = parser.parse_args()
    
    # Resolve paths relative to e2e-tests directory
    e2e_dir = Path(__file__).parent.resolve()
    input_path = e2e_dir / args.input
    output_path = e2e_dir / args.output
    
    # Read results
    try:
        with open(input_path) as f:
            results = json.load(f)
    except FileNotFoundError:
        print(f"Error: Input file not found: {input_path}")
        print("Run 'python benchmark_orchestrator.py' first to generate results.")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in input file: {e}")
        sys.exit(1)
    
    # Generate report
    report = generate_report(results)
    
    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        f.write(report)
    
    print(f"Report generated: {output_path}")


if __name__ == "__main__":
    main()
