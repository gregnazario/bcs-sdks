# Releasing BCS SDKs

This document describes how to release new versions of the BCS SDKs.

## Overview

Each SDK in this repository can be released independently. Releases are automated via GitHub Actions, triggered by pushing git tags in the format `{sdk}-v{version}` (e.g., `python-v1.2.0`).

## Quick Start

```bash
# Release a new version of a specific SDK
./scripts/release.py python 1.2.0

# Preview what would happen (no changes made)
./scripts/release.py python 1.2.0 --dry-run

# Create commit and tag but don't push (for review)
./scripts/release.py python 1.2.0 --no-push

# List all SDKs and their current versions
./scripts/release.py --list
```

## Release Process

The release script automates the following steps:

1. **Validates** the SDK name and semantic version
2. **Updates** the version in the SDK's package configuration file(s)
3. **Updates** the SDK's `CHANGELOG.md`
4. **Commits** the version bump with message `chore({sdk}): release v{version}`
5. **Tags** the commit with `{sdk}-v{version}`
6. **Pushes** the commit and tag to trigger the publish workflow

## Supported SDKs

| SDK | Package Registry | Tag Pattern |
|-----|-----------------|-------------|
| `c` | *(git tags only)* | `c-v*` |
| `cpp` | *(git tags only)* | `cpp-v*` |
| `csharp` | [NuGet](https://www.nuget.org/) | `csharp-v*` |
| `dart` | [pub.dev](https://pub.dev/) | `dart-v*` |
| `elixir` | [Hex.pm](https://hex.pm/) | `elixir-v*` |
| `go` | [Go Proxy](https://proxy.golang.org/) | `go-v*` |
| `java` | [Maven Central](https://central.sonatype.com/) | `java-v*` |
| `kotlin` | [Maven Central](https://central.sonatype.com/) | `kotlin-v*` |
| `ocaml` | [OPAM](https://opam.ocaml.org/) | `ocaml-v*` |
| `python` | [PyPI](https://pypi.org/) | `python-v*` |
| `ruby` | [RubyGems](https://rubygems.org/) | `ruby-v*` |
| `rust` | [crates.io](https://crates.io/) | `rust-v*` |
| `swift` | [Swift Package Index](https://swiftpackageindex.com/) | `swift-v*` |
| `typescript` | [npm](https://www.npmjs.com/) | `typescript-v*` |
| `zig` | *(git tags only)* | `zig-v*` |

## Prerequisites

### 1. Clean Working Directory

The release script requires a clean git working directory:

```bash
git status  # Should show no uncommitted changes
```

### 2. Main Branch

Releases should typically be made from the `main` branch:

```bash
git checkout main
git pull origin main
```

### 3. Required Secrets

The GitHub repository must have the following secrets configured for automated publishing:

#### PyPI (Python)
- Uses [Trusted Publishing](https://docs.pypi.org/trusted-publishers/) (OIDC)
- Configure in PyPI project settings, no secret needed
- GitHub environment: `pypi`

#### npm (TypeScript)
- `NPM_TOKEN` - npm access token with publish permissions
- GitHub environment: `npm`

#### Hex.pm (Elixir/Erlang)
- `HEX_API_KEY` - Hex.pm API key
- GitHub environment: `hex`

#### Maven Central (Java/Kotlin/Groovy)
- `MAVEN_USERNAME` - Sonatype OSSRH username
- `MAVEN_PASSWORD` - Sonatype OSSRH password
- `MAVEN_GPG_PRIVATE_KEY` - GPG private key for signing
- `MAVEN_GPG_PASSPHRASE` - GPG key passphrase
- GitHub environment: `maven`

#### NuGet (C#)
- `NUGET_API_KEY` - NuGet API key
- GitHub environment: `nuget`

#### crates.io (Rust)
- `CRATES_TOKEN` - crates.io API token
- GitHub environment: `crates`

#### RubyGems (Ruby)
- `RUBYGEMS_API_KEY` - RubyGems API key
- GitHub environment: `rubygems`

#### pub.dev (Dart)
- `PUB_CREDENTIALS` - pub.dev credentials JSON
- GitHub environment: `pub`

#### Packagist (PHP)
- `PACKAGIST_USERNAME` - Packagist username
- `PACKAGIST_TOKEN` - Packagist API token

#### Hackage (Haskell)
- `HACKAGE_USERNAME` - Hackage username
- `HACKAGE_PASSWORD` - Hackage password
- GitHub environment: `hackage`

#### LuaRocks (Lua)
- `LUAROCKS_API_KEY` - LuaRocks API key
- GitHub environment: `luarocks`

#### CPAN (Perl)
- `CPAN_USERNAME` - CPAN username
- `CPAN_PASSWORD` - CPAN password
- GitHub environment: `cpan`

#### PSGallery (PowerShell)
- `PSGALLERY_API_KEY` - PowerShell Gallery API key
- GitHub environment: `psgallery`

## Versioning Guidelines

All SDKs follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Pre-release Versions

Pre-release versions are supported:

```bash
./scripts/release.py python 2.0.0-alpha.1
./scripts/release.py python 2.0.0-beta.1
./scripts/release.py python 2.0.0-rc.1
```

## Writing Changelog Entries

Before releasing, update the changelog with details about the changes:

1. Open `sdks/{sdk}/CHANGELOG.md`
2. Add entries under the `[Unreleased]` section
3. The release script will move these to the new version section

### Changelog Format

```markdown
## [Unreleased]

### Added
- New feature description

### Changed
- Changed behavior description

### Fixed
- Bug fix description

### Deprecated
- Deprecated feature description

### Removed
- Removed feature description

### Security
- Security fix description
```

## Manual Release (Advanced)

If you need to release manually without the script:

```bash
# 1. Update version in package file(s)
# 2. Update CHANGELOG.md
# 3. Commit changes
git add sdks/python/
git commit -m "chore(python): release v1.2.0"

# 4. Create and push tag
git tag -a python-v1.2.0 -m "Release python v1.2.0"
git push origin main python-v1.2.0
```

## Troubleshooting

### Tag Already Exists

```
Error: Tag python-v1.2.0 already exists
```

Either use a different version number, or delete the existing tag (if it was never published):

```bash
git tag -d python-v1.2.0
git push origin :refs/tags/python-v1.2.0
```

### Working Directory Not Clean

```
Error: Working directory is not clean
```

Commit or stash your changes before releasing:

```bash
git stash  # or git commit
./scripts/release.py python 1.2.0
git stash pop  # if you stashed
```

### Publish Failed

If the GitHub Action fails after the tag is pushed:

1. Check the [Actions tab](../../actions) for error details
2. Fix the issue (usually missing secrets or permission problems)
3. Re-run the failed workflow, or delete the tag and re-release

### Version Mismatch

If the version in the package file doesn't match the tag, some registries will reject the package. The release script ensures they match, but if releasing manually, double-check.

## Platform-Specific Notes

### Go Modules

Go doesn't use a version file. The version comes from the git tag. The Go Proxy automatically indexes new tags.

```bash
# Users install with:
go get github.com/bcs-sdks/bcs-go@v1.2.0
```

### Swift Package Manager

Swift uses git tags directly. The Swift Package Index automatically discovers new tags.

```swift
// Users add to Package.swift:
.package(url: "https://github.com/bcs-sdks/bcs-sdks", from: "1.0.0")
```

### OCaml/OPAM

OPAM packages require a PR to the [opam-repository](https://github.com/ocaml/opam-repository). The publish workflow creates the release, but manual submission may be needed.

### C/C++

These are header-only libraries distributed via git. Users typically use FetchContent (CMake) or copy the headers directly.
