#!/usr/bin/env python3
"""
Release automation script for BCS SDKs.

Usage:
    ./scripts/release.py <sdk> <version> [--dry-run] [--no-push]

Examples:
    ./scripts/release.py python 1.2.0
    ./scripts/release.py rust 0.2.0 --dry-run
    ./scripts/release.py typescript 2.0.0 --no-push
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Optional

# Root of the repository
REPO_ROOT = Path(__file__).parent.parent.absolute()
SDKS_DIR = REPO_ROOT / "sdks"

# SDK configurations: maps SDK name to version file info
SDK_CONFIGS = {
    "python": {
        "files": [
            {
                "path": "pyproject.toml",
                "pattern": r'^version = "[^"]+"',
                "replacement": 'version = "{version}"',
                "multiline": True,
            }
        ],
    },
    "typescript": {
        "files": [
            {
                "path": "package.json",
                "type": "json",
                "key": "version",
            }
        ],
    },
    "rust": {
        "files": [
            {
                "path": "Cargo.toml",
                "pattern": r'^version = "[^"]+"',
                "replacement": 'version = "{version}"',
                "multiline": True,
            }
        ],
    },
    "java": {
        "files": [
            {
                "path": "pom.xml",
                "pattern": r"(<artifactId>bcs</artifactId>\s*\n\s*<version>)[^<]+(</version>)",
                "replacement": r"\g<1>{version}\g<2>",
                "multiline": True,
            }
        ],
    },
    "kotlin": {
        "files": [
            {
                "path": "build.gradle.kts",
                "pattern": r'^version = "[^"]+"',
                "replacement": 'version = "{version}"',
                "multiline": True,
            }
        ],
    },
    "csharp": {
        "files": [
            {
                "path": "Bcs/Bcs.csproj",
                "pattern": r"<Version>[^<]+</Version>",
                "replacement": "<Version>{version}</Version>",
            }
        ],
    },
    "ruby": {
        "files": [
            {
                "path": "lib/bcs/version.rb",
                "pattern": r'VERSION = "[^"]+"',
                "replacement": 'VERSION = "{version}"',
            },
            {
                "path": "bcs.gemspec",
                "pattern": r'spec\.version\s*=\s*"[^"]+"',
                "replacement": 'spec.version       = "{version}"',
            },
        ],
    },
    "go": {
        # Go uses git tags only, no version file to update
        "files": [],
    },
    "swift": {
        # Swift uses git tags only, no version file to update
        "files": [],
    },
    "dart": {
        "files": [
            {
                "path": "pubspec.yaml",
                "pattern": r"^version: .+$",
                "replacement": "version: {version}",
                "multiline": True,
            }
        ],
    },
    "elixir": {
        "files": [
            {
                "path": "mix.exs",
                "pattern": r'@version "[^"]+"',
                "replacement": '@version "{version}"',
            }
        ],
    },
    "ocaml": {
        "files": [
            {
                "path": "dune-project",
                "pattern": r"\(version [^\)]+\)",
                "replacement": "(version {version})",
            },
            # bcs.opam is auto-generated from dune-project, but we update it anyway
            {
                "path": "bcs.opam",
                "pattern": r'^version: "[^"]+"',
                "replacement": 'version: "{version}"',
                "multiline": True,
            },
        ],
    },
    "cpp": {
        "files": [
            {
                "path": "CMakeLists.txt",
                "pattern": r"project\(bcs VERSION [^\s]+ LANGUAGES",
                "replacement": "project(bcs VERSION {version} LANGUAGES",
            }
        ],
    },
    "c": {
        # C is header-only, uses git tags
        "files": [],
    },
    "zig": {
        "files": [
            {
                "path": "build.zig.zon",
                "pattern": r'\.version = "[^"]+"',
                "replacement": '.version = "{version}"',
            }
        ],
    },
}

# Valid SDK names
VALID_SDKS = list(SDK_CONFIGS.keys())


def validate_semver(version: str) -> bool:
    """Validate that version follows semantic versioning."""
    pattern = r"^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$"
    return bool(re.match(pattern, version))


def run_command(
    cmd: list[str], cwd: Optional[Path] = None, check: bool = True
) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"Error running command: {' '.join(cmd)}")
        print(f"stdout: {result.stdout}")
        print(f"stderr: {result.stderr}")
        sys.exit(1)
    return result


def update_json_version(file_path: Path, key: str, version: str, dry_run: bool) -> None:
    """Update version in a JSON file."""
    with open(file_path, "r") as f:
        data = json.load(f)

    old_version = data.get(key, "unknown")
    data[key] = version

    print(f"  {file_path.name}: {old_version} -> {version}")

    if not dry_run:
        with open(file_path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")  # Add trailing newline


def update_regex_version(
    file_path: Path,
    pattern: str,
    replacement: str,
    version: str,
    dry_run: bool,
    multiline: bool = False,
) -> None:
    """Update version in a file using regex replacement."""
    with open(file_path, "r") as f:
        content = f.read()

    flags = re.MULTILINE if multiline else 0
    replacement_with_version = replacement.format(version=version)

    # Find current version for display
    match = re.search(pattern, content, flags)
    if match:
        old_text = match.group(0)
        print(f"  {file_path.name}: found match, updating...")
    else:
        print(f"  WARNING: Pattern not found in {file_path.name}")
        return

    new_content = re.sub(pattern, replacement_with_version, content, count=1, flags=flags)

    if not dry_run:
        with open(file_path, "w") as f:
            f.write(new_content)


def update_changelog(sdk_dir: Path, version: str, dry_run: bool) -> None:
    """Update the CHANGELOG.md for the SDK."""
    changelog_path = sdk_dir / "CHANGELOG.md"
    today = date.today().isoformat()

    if not changelog_path.exists():
        print(f"  Creating new CHANGELOG.md")
        content = f"""# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [{version}] - {today}

### Added

- Initial release
"""
    else:
        with open(changelog_path, "r") as f:
            content = f.read()

        # Check if version already exists
        if f"## [{version}]" in content:
            print(f"  WARNING: Version {version} already exists in CHANGELOG.md, skipping")
            return

        # Find the [Unreleased] section and add the new version after it
        unreleased_pattern = r"(## \[Unreleased\].*?)(\n## \[)"
        if re.search(unreleased_pattern, content, re.DOTALL):
            # There's content between Unreleased and the next version
            new_section = f"\n\n## [{version}] - {today}\n"
            content = re.sub(
                unreleased_pattern,
                rf"\1{new_section}\2",
                content,
                count=1,
                flags=re.DOTALL,
            )
        else:
            # No previous versions, add after Unreleased
            unreleased_simple = r"(## \[Unreleased\])"
            new_section = f"\n\n## [{version}] - {today}\n\n### Added\n\n- Release {version}"
            content = re.sub(
                unreleased_simple,
                rf"\1{new_section}",
                content,
                count=1,
            )

        print(f"  Updated CHANGELOG.md with version {version}")

    if not dry_run:
        with open(changelog_path, "w") as f:
            f.write(content)


def get_current_version(sdk: str) -> Optional[str]:
    """Get the current version from the SDK's version file."""
    config = SDK_CONFIGS[sdk]
    if not config["files"]:
        # Check git tags for SDKs without version files
        result = run_command(
            ["git", "tag", "-l", f"{sdk}-v*", "--sort=-version:refname"],
            cwd=REPO_ROOT,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            latest_tag = result.stdout.strip().split("\n")[0]
            return latest_tag.replace(f"{sdk}-v", "")
        return None

    file_config = config["files"][0]
    file_path = SDKS_DIR / sdk / file_config["path"]

    if not file_path.exists():
        return None

    with open(file_path, "r") as f:
        content = f.read()

    if file_config.get("type") == "json":
        data = json.loads(content)
        return data.get(file_config["key"])
    else:
        pattern = file_config["pattern"]
        match = re.search(pattern, content, re.MULTILINE if file_config.get("multiline") else 0)
        if match:
            # Extract version from the match
            version_match = re.search(r'[\d]+\.[\d]+\.[\d]+(?:-[a-zA-Z0-9.]+)?', match.group(0))
            if version_match:
                return version_match.group(0)
    return None


def release_sdk(sdk: str, version: str, dry_run: bool = False, no_push: bool = False) -> None:
    """Release a new version of an SDK."""
    print(f"\n{'=' * 60}")
    print(f"Releasing {sdk} v{version}" + (" (DRY RUN)" if dry_run else ""))
    print(f"{'=' * 60}\n")

    sdk_dir = SDKS_DIR / sdk
    if not sdk_dir.exists():
        print(f"Error: SDK directory not found: {sdk_dir}")
        sys.exit(1)

    config = SDK_CONFIGS[sdk]
    tag_name = f"{sdk}-v{version}"

    # Check if tag already exists
    result = run_command(["git", "tag", "-l", tag_name], cwd=REPO_ROOT, check=False)
    if result.stdout.strip() == tag_name:
        print(f"Error: Tag {tag_name} already exists")
        sys.exit(1)

    # Get current version
    current_version = get_current_version(sdk)
    if current_version:
        print(f"Current version: {current_version}")
    print(f"New version: {version}\n")

    # Update version files
    print("Updating version files:")
    for file_config in config["files"]:
        file_path = sdk_dir / file_config["path"]
        if not file_path.exists():
            print(f"  WARNING: File not found: {file_path}")
            continue

        if file_config.get("type") == "json":
            update_json_version(file_path, file_config["key"], version, dry_run)
        else:
            update_regex_version(
                file_path,
                file_config["pattern"],
                file_config["replacement"],
                version,
                dry_run,
                file_config.get("multiline", False),
            )

    if not config["files"]:
        print("  (no version files to update - uses git tags only)")

    # Update changelog
    print("\nUpdating changelog:")
    update_changelog(sdk_dir, version, dry_run)

    if dry_run:
        print("\n[DRY RUN] Would commit and tag changes")
        print(f"[DRY RUN] Tag: {tag_name}")
        return

    # Git operations
    print("\nCommitting changes:")

    # Stage changes
    files_to_add = [str(sdk_dir / "CHANGELOG.md")]
    for file_config in config["files"]:
        files_to_add.append(str(sdk_dir / file_config["path"]))

    for file_path in files_to_add:
        if Path(file_path).exists():
            run_command(["git", "add", file_path], cwd=REPO_ROOT)

    # Commit
    commit_message = f"chore({sdk}): release v{version}"
    run_command(["git", "commit", "-m", commit_message], cwd=REPO_ROOT)
    print(f"  Committed: {commit_message}")

    # Create tag
    print(f"\nCreating tag: {tag_name}")
    run_command(["git", "tag", "-a", tag_name, "-m", f"Release {sdk} v{version}"], cwd=REPO_ROOT)

    if no_push:
        print("\n[--no-push] Skipping push to remote")
        print(f"  To push manually: git push origin main {tag_name}")
    else:
        print("\nPushing to remote:")
        run_command(["git", "push", "origin", "HEAD"], cwd=REPO_ROOT)
        run_command(["git", "push", "origin", tag_name], cwd=REPO_ROOT)
        print(f"  Pushed commit and tag {tag_name}")

    print(f"\n{'=' * 60}")
    print(f"Successfully released {sdk} v{version}!")
    print(f"{'=' * 60}")


def list_sdks() -> None:
    """List all available SDKs and their current versions."""
    print("\nAvailable SDKs:\n")
    print(f"{'SDK':<15} {'Current Version':<15} {'Version File'}")
    print("-" * 60)

    for sdk in sorted(VALID_SDKS):
        version = get_current_version(sdk) or "unknown"
        config = SDK_CONFIGS[sdk]
        if config["files"]:
            version_file = config["files"][0]["path"]
        else:
            version_file = "(git tags only)"
        print(f"{sdk:<15} {version:<15} {version_file}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Release automation for BCS SDKs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s python 1.2.0              # Release Python SDK v1.2.0
  %(prog)s rust 0.2.0 --dry-run      # Preview Rust release
  %(prog)s --list                    # Show all SDKs and versions
        """,
    )
    parser.add_argument("sdk", nargs="?", help=f"SDK to release: {', '.join(VALID_SDKS)}")
    parser.add_argument("version", nargs="?", help="Version to release (semver format)")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without committing")
    parser.add_argument(
        "--no-push", action="store_true", help="Commit and tag but don't push to remote"
    )
    parser.add_argument("--list", action="store_true", help="List all SDKs and their versions")

    args = parser.parse_args()

    if args.list:
        list_sdks()
        return

    if not args.sdk or not args.version:
        parser.print_help()
        sys.exit(1)

    # Validate SDK name
    if args.sdk not in VALID_SDKS:
        print(f"Error: Unknown SDK '{args.sdk}'")
        print(f"Valid SDKs: {', '.join(VALID_SDKS)}")
        sys.exit(1)

    # Validate version format
    if not validate_semver(args.version):
        print(f"Error: Invalid version format '{args.version}'")
        print("Version must follow semantic versioning (e.g., 1.2.3, 1.0.0-beta.1)")
        sys.exit(1)

    # Check for clean working directory (unless dry-run)
    if not args.dry_run:
        result = run_command(["git", "status", "--porcelain"], cwd=REPO_ROOT, check=False)
        if result.stdout.strip():
            print("Error: Working directory is not clean")
            print("Please commit or stash your changes before releasing")
            print(f"\nModified files:\n{result.stdout}")
            sys.exit(1)

    release_sdk(args.sdk, args.version, args.dry_run, args.no_push)


if __name__ == "__main__":
    main()
