# dot-bin -- Developer Guide

## Overview

Manages portable CLI tool binaries with automated updates from upstream GitHub/GitLab releases. Each tool is defined by a JSON file in `packages/`, and `scripts/update.sh` handles downloading, verifying, extracting, and installing binaries for both x86_64 and arm64 architectures. CI publishes release tarballs to GitHub Releases; users install via `curl | bash`.

## Quick Reference

```bash
# Update all packages to latest upstream versions (local dev)
./scripts/update.sh

# Update specific packages
./scripts/update.sh nvim lazygit gh

# Update to a custom output directory
DOT_BIN_DIR=/tmp/staging/bin ./scripts/update.sh

# Override release channel at runtime (stable or unstable)
CHANNEL=unstable ./scripts/update.sh nvim

# Verify a binary after install
file bin/x86_64/<name>    # should show "ELF 64-bit LSB ... x86-64"
file bin/arm64/<name>     # should show "ELF 64-bit LSB ... ARM aarch64"

# List release assets for a GitHub repo (useful when adding packages)
gh release view --repo <owner/repo> --json assets --jq '.assets[].name'

# Check current installed versions
cat versions.json
```

## Package JSON Format

Each package is defined in `packages/<name>.json`. Fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Package identifier, must match filename |
| `repo` | string | yes* | GitHub `owner/repo` (*omit for GitLab sources) |
| `source` | string | no | `"github"` (default) or `"gitlab"` |
| `gitlab_project` | string | no | URL-encoded GitLab project path (required when `source` is `"gitlab"`) |
| `tag_prefix` | string | no | Prefix stripped from git tag to get version (e.g. `"v"`, `"cli-v"`, `"jq-"`, `""`) |
| `channel` | string | no | `"stable"` (default) or `"unstable"` — stable uses latest non-pre-release; unstable includes pre-releases |
| `format` | string | yes | `"tarball"`, `"zip"`, or `"binary"` |
| `output_binaries` | string[] | yes | Binary names placed in `bin/{arch}/` |
| `checksum.asset` | string | no | Checksum filename in the release (supports `{version}` placeholder) |
| `checksum.algorithm` | string | no | `"sha256"` or `"sha512"` |
| `architectures` | object | yes | Per-arch download and extract config (keys: `x86_64`, `arm64`) |
| `architectures.{arch}.asset_pattern` | string | yes | Download filename (supports `{version}` placeholder) |
| `architectures.{arch}.extract_path` | string or string[] | no | Path inside archive; use array for multi-binary packages; supports wildcards (e.g. `*/bin/gh`) |
| `architectures.{arch}.checksum_asset` | string | no | Per-arch checksum file, overrides `checksum.asset` (for per-asset checksums) |

### Examples

Simple tarball with checksum (`lazygit`):
```json
{
  "name": "lazygit",
  "repo": "jesseduffield/lazygit",
  "tag_prefix": "v",
  "format": "tarball",
  "output_binaries": ["lazygit"],
  "checksum": { "asset": "checksums.txt", "algorithm": "sha256" },
  "architectures": {
    "x86_64": { "asset_pattern": "lazygit_{version}_linux_x86_64.tar.gz", "extract_path": "lazygit" },
    "arm64": { "asset_pattern": "lazygit_{version}_linux_arm64.tar.gz", "extract_path": "lazygit" }
  }
}
```

Standalone binary, no archive (`jq`):
```json
{
  "name": "jq",
  "repo": "jqlang/jq",
  "tag_prefix": "jq-",
  "format": "binary",
  "output_binaries": ["jq"],
  "checksum": { "asset": "sha256sum.txt", "algorithm": "sha256" },
  "architectures": {
    "x86_64": { "asset_pattern": "jq-linux-amd64" },
    "arm64": { "asset_pattern": "jq-linux-arm64" }
  }
}
```

Multi-binary with per-asset checksums (`uv`):
```json
{
  "name": "uv",
  "repo": "astral-sh/uv",
  "tag_prefix": "",
  "format": "tarball",
  "output_binaries": ["uv", "uvx"],
  "checksum": { "algorithm": "sha256" },
  "architectures": {
    "x86_64": {
      "asset_pattern": "uv-x86_64-unknown-linux-gnu.tar.gz",
      "extract_path": ["uv-x86_64-unknown-linux-gnu/uv", "uv-x86_64-unknown-linux-gnu/uvx"],
      "checksum_asset": "uv-x86_64-unknown-linux-gnu.tar.gz.sha256"
    },
    "arm64": {
      "asset_pattern": "uv-aarch64-unknown-linux-gnu.tar.gz",
      "extract_path": ["uv-aarch64-unknown-linux-gnu/uv", "uv-aarch64-unknown-linux-gnu/uvx"],
      "checksum_asset": "uv-aarch64-unknown-linux-gnu.tar.gz.sha256"
    }
  }
}
```

GitLab source (`glab`):
```json
{
  "name": "glab",
  "source": "gitlab",
  "gitlab_project": "gitlab-org%2Fcli",
  "tag_prefix": "v",
  "format": "tarball",
  "output_binaries": ["glab"],
  "checksum": { "asset": "checksums.txt", "algorithm": "sha256" },
  "architectures": {
    "x86_64": { "asset_pattern": "glab_{version}_linux_amd64.tar.gz", "extract_path": "bin/glab" },
    "arm64": { "asset_pattern": "glab_{version}_linux_arm64.tar.gz", "extract_path": "bin/glab" }
  }
}
```

## Adding a New Package

1. Find the repo and examine its latest release assets
2. Identify Linux x86_64 and arm64 asset filenames
3. Determine format (`tarball`/`zip`/`binary`), tag prefix, and whether checksums exist
4. For archives, download one and list contents to find the binary path inside
5. Create `packages/<name>.json` with all required fields
6. Run `./scripts/update.sh <name>` to test
7. Verify binaries: `file bin/x86_64/<name>` and `file bin/arm64/<name>`
8. Commit: `git add packages/<name>.json versions.json`

## Architecture

### Scripts

**`scripts/lib.sh`** -- shared functions sourced by update.sh:
- `BIN_DIR="${DOT_BIN_DIR:-${REPO_ROOT}/bin}"` -- output directory, overridable via env var
- `ARCHITECTURES=("x86_64" "arm64")` -- supported architectures
- `get_current_version(name)` -- reads version from `versions.json`
- `set_version(name, version)` -- writes version to `versions.json`
- `strip_prefix(tag, prefix)` -- removes tag prefix to get clean version
- `get_latest_tag(pkg_file)` -- queries GitHub API (`gh api`) or GitLab API for latest release tag; respects `channel` setting (`stable`/`unstable`) and `CHANNEL` env var override
- `download_asset(pkg_file, tag, dest_dir, arch)` -- downloads the per-arch release asset via `gh release download` (GitHub) or `curl` (GitLab)
- `download_checksum_file(pkg_file, tag, dest_dir, arch)` -- downloads checksum file, respects arch-specific overrides
- `verify_checksum(pkg_file, asset_name, asset_path, tag, arch)` -- validates SHA256/512 against downloaded checksum file
- `resolve_path(base_dir, pattern)` -- resolves extract paths including wildcard/glob patterns
- `install_binary(pkg_file, tmpdir, asset_name, arch)` -- extracts (tar/zip) or copies (binary) to `bin/{arch}/`
- `install_extracted(pkg_file, tmpdir, arch)` -- handles single and array extract_path, supports wildcards
- `download_and_install(pkg_file, tag)` -- orchestrates the full per-arch loop: download, verify, install, update version

**`scripts/update.sh`** -- main driver:
- Accepts optional package names as arguments (defaults to all)
- For each package: fetches latest tag, compares to current version, downloads and installs if newer
- Exits with code 1 if any package failed

**`scripts/release-notes.py`** -- generates markdown release notes by diffing old/new `versions.json`

**`install.sh`** -- user-facing install/update script:
- Detects architecture (`uname -m`)
- Downloads latest release tarball via GitHub API
- Verifies SHA256 checksum
- Extracts to `~/.local/bin/` (or `$DOT_BIN_INSTALL_DIR`)

### Update Flow

```
update.sh [pkg...]
  for each package:
    get_latest_tag()          -- fetch latest release tag from API
    compare with versions.json
    if newer:
      for each arch (x86_64, arm64):
        download_asset()      -- download release asset to tmpdir
        verify_checksum()     -- validate if checksum configured
        install_binary()      -- extract/copy to bin/{arch}/
      set_version()           -- update versions.json
```

### CI

GitHub Actions (`.github/workflows/update.yml`) runs daily at 06:00 UTC and can be triggered manually with optional package filter and force flag.

CI flow:
1. Checks out repo (no LFS)
2. Fetches previous `versions.json` from latest release
3. Runs `update.sh` with `DOT_BIN_DIR` pointing to staging directory
4. Skips release if `versions.json` unchanged (unless force=true)
5. Creates `dot-bin-{arch}.tar.gz` tarballs with SHA256 checksums
6. Publishes date-tagged GitHub Release with tarballs + checksums + versions.json
7. Commits only `versions.json` to the repo

### Release Distribution

- **Tagging**: Date-based (`2026-03-16`), with `.N` suffix for same-day duplicates
- **Tarball structure**: Flat binaries at top level — `tar xzf dot-bin-x86_64.tar.gz -C ~/.local/bin/` just works
- **Install**: `curl -fsSL .../install.sh | bash` downloads latest release to `~/.local/bin/`

## Conventions

- **Bash style**: `set -euo pipefail` at top of every script; pass shellcheck
- **JSON**: 2-space indent, one package per file in `packages/`, filename matches `name` field
- **bin/**: Gitignored, not tracked in the repo. Binaries are distributed via GitHub Releases
- **versions.json**: Auto-generated by update.sh, do not edit manually
- **Commit messages**: Conventional commits (`feat:` for new packages, `chore:` for updates, `fix:` for bug fixes)
