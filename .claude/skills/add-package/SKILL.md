# Add Package Skill

Add a new CLI tool to dot-bin, with binary downloads from GitHub or GitLab releases.

## When to use

- User asks to add a new CLI tool/binary to the repo
- User provides a tool name or GitHub/GitLab repo URL

## Prerequisites

- `gh` CLI authenticated (for GitHub API and release downloads)
- `jq`, `tar`, `unzip`, `file` available on PATH

## Workflow

### Step 1: Research the tool

Given a tool name or repo URL, gather all the information needed to create the package definition.

**Find the repo** (if only a tool name is given):
```bash
gh search repos "<tool-name>" --limit 5 --json fullName,description,stargazersCount
```

**List release assets** to identify Linux x86_64 and arm64 downloads:
```bash
gh release view --repo <owner/repo> --json assets --jq '.assets[].name'
```
If the tool uses pre-releases, list all releases instead:
```bash
gh release list --repo <owner/repo> --limit 5
gh release view <tag> --repo <owner/repo> --json assets --jq '.assets[].name'
```

**Determine tag prefix** by examining recent tags:
```bash
gh release list --repo <owner/repo> --limit 5 --json tagName --jq '.[].tagName'
```
Common patterns:
- `v1.2.3` -> tag_prefix: `"v"`
- `jq-1.7.1` -> tag_prefix: `"jq-"`
- `cli-v2024.1.0` -> tag_prefix: `"cli-v"`
- `1.2.3` (no prefix) -> tag_prefix: `""`

**Identify the format**:
- `.tar.gz` -> `"tarball"`
- `.zip` -> `"zip"`
- No extension / raw binary -> `"binary"`

**Check for checksums** -- look for assets like:
- `checksums.txt`, `checksums.sha256`, `sha256sum.txt`
- Per-asset: `<asset>.sha256` (e.g. `uv-x86_64-unknown-linux-gnu.tar.gz.sha256`)
- Version-templated: `gh_{version}_checksums.txt`, `sesh_{version}_checksums.txt`

**Identify architecture naming** in the asset filenames:
- x86_64 variants: `x86_64`, `amd64`, `linux-x64`, `x86_64-unknown-linux-gnu`, `x86_64-unknown-linux-musl`
- arm64 variants: `arm64`, `aarch64`, `linux-arm64`, `aarch64-unknown-linux-gnu`, `aarch64-unknown-linux-musl`

### Step 2: Determine extract path (for archives only)

Skip this step for `"binary"` format.

Download a release asset and inspect its contents:
```bash
# For tarballs:
gh release download <tag> --repo <owner/repo> --pattern "<asset>" --dir /tmp
tar tzf /tmp/<asset>

# For zips:
unzip -l /tmp/<asset>
```

Determine where the binary lives inside the archive:
- Top-level: `extract_path: "toolname"` (e.g. lazygit, zellij)
- Nested: `extract_path: "dir/bin/toolname"` (e.g. nvim-linux-x86_64/bin/nvim)
- Variable top-level dir: `extract_path: "*/bin/toolname"` (uses wildcard, e.g. gh)
- Multiple binaries: `extract_path: ["dir/bin1", "dir/bin2"]` (e.g. uv + uvx)

### Step 3: Create the package JSON

Write `packages/<name>.json`. Use the appropriate template based on what you discovered:

**Simple tarball with checksum** (most common):
```json
{
  "name": "<name>",
  "repo": "<owner/repo>",
  "tag_prefix": "v",
  "format": "tarball",
  "output_binaries": ["<name>"],
  "checksum": {
    "asset": "checksums.txt",
    "algorithm": "sha256"
  },
  "architectures": {
    "x86_64": {
      "asset_pattern": "<name>_{version}_linux_x86_64.tar.gz",
      "extract_path": "<name>"
    },
    "arm64": {
      "asset_pattern": "<name>_{version}_linux_arm64.tar.gz",
      "extract_path": "<name>"
    }
  }
}
```

**Standalone binary (no archive)**:
```json
{
  "name": "<name>",
  "repo": "<owner/repo>",
  "tag_prefix": "v",
  "format": "binary",
  "output_binaries": ["<name>"],
  "architectures": {
    "x86_64": {
      "asset_pattern": "<name>-linux-amd64"
    },
    "arm64": {
      "asset_pattern": "<name>-linux-arm64"
    }
  }
}
```

**GitLab source**:
```json
{
  "name": "<name>",
  "source": "gitlab",
  "gitlab_project": "<url-encoded-project-path>",
  "tag_prefix": "v",
  "format": "tarball",
  "output_binaries": ["<name>"],
  "architectures": {
    "x86_64": {
      "asset_pattern": "<name>_{version}_linux_amd64.tar.gz",
      "extract_path": "<name>"
    },
    "arm64": {
      "asset_pattern": "<name>_{version}_linux_arm64.tar.gz",
      "extract_path": "<name>"
    }
  }
}
```

**Multi-binary with per-asset checksums** (when each asset has its own `.sha256` file):
```json
{
  "name": "<name>",
  "repo": "<owner/repo>",
  "tag_prefix": "",
  "format": "tarball",
  "output_binaries": ["<bin1>", "<bin2>"],
  "checksum": {
    "algorithm": "sha256"
  },
  "architectures": {
    "x86_64": {
      "asset_pattern": "<asset-x86_64>.tar.gz",
      "extract_path": ["<dir>/bin1", "<dir>/bin2"],
      "checksum_asset": "<asset-x86_64>.tar.gz.sha256"
    },
    "arm64": {
      "asset_pattern": "<asset-arm64>.tar.gz",
      "extract_path": ["<dir>/bin1", "<dir>/bin2"],
      "checksum_asset": "<asset-arm64>.tar.gz.sha256"
    }
  }
}
```

**Pre-release package** (for tools where latest stable is not tagged as `latest`):
```json
{
  "name": "<name>",
  "repo": "<owner/repo>",
  "tag_prefix": "v",
  "pre_release": true,
  "format": "tarball",
  "output_binaries": ["<name>"],
  "architectures": {
    "x86_64": {
      "asset_pattern": "<asset-x86_64>.tar.gz",
      "extract_path": "<name>"
    },
    "arm64": {
      "asset_pattern": "<asset-arm64>.tar.gz",
      "extract_path": "<name>"
    }
  }
}
```

### Field reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Package identifier, must match filename |
| `repo` | string | yes* | GitHub `owner/repo` (*omit for GitLab) |
| `source` | string | no | `"github"` (default) or `"gitlab"` |
| `gitlab_project` | string | no | URL-encoded GitLab project path (required when source is gitlab) |
| `tag_prefix` | string | no | Stripped from tag to get version (default: `""`) |
| `pre_release` | bool | no | Include pre-release tags (default: false) |
| `format` | string | yes | `"tarball"`, `"zip"`, or `"binary"` |
| `output_binaries` | string[] | yes | Binary names placed in `bin/{arch}/` |
| `checksum.asset` | string | no | Checksum filename (`{version}` placeholder supported) |
| `checksum.algorithm` | string | no | `"sha256"` or `"sha512"` |
| `architectures.{arch}.asset_pattern` | string | yes | Download filename (`{version}` placeholder supported) |
| `architectures.{arch}.extract_path` | string/string[] | no | Path(s) inside archive; supports wildcards |
| `architectures.{arch}.checksum_asset` | string | no | Per-arch checksum file, overrides `checksum.asset` |

### Step 4: Test the download

Run the update script for the new package:
```bash
./scripts/update.sh <name>
```

Verify:
1. Both architectures downloaded and installed:
   ```bash
   ls -la bin/x86_64/<name> bin/arm64/<name>
   ```

2. Binaries are valid ELF executables:
   ```bash
   file bin/x86_64/<name>
   # Expected: ELF 64-bit LSB ... x86-64
   file bin/arm64/<name>
   # Expected: ELF 64-bit LSB ... ARM aarch64
   ```

3. Version was recorded:
   ```bash
   jq '.<name>' versions.json
   ```

4. If checksum is configured, look for "Checksum verified" in the output

If the download fails, common issues:
- **Wrong asset_pattern**: Re-check `gh release view` output for exact filenames; remember `{version}` is the version without the tag prefix
- **Wrong extract_path**: Re-list archive contents with `tar tzf` or `unzip -l`
- **Checksum mismatch**: Verify the checksum asset name matches what the release publishes; check if it is per-asset vs combined
- **No arm64 asset**: Some tools only publish x86_64; remove the arm64 entry from architectures

### Step 5: Commit

```bash
git add packages/<name>.json versions.json
git commit -m "feat: add <name> package"
```

## Real examples from this repo

### lazygit -- typical tarball with combined checksum file
- Tag prefix: `v` (tags like `v0.60.0`)
- Assets: `lazygit_0.60.0_linux_x86_64.tar.gz`, `lazygit_0.60.0_linux_arm64.tar.gz`
- Checksum: `checksums.txt` (combined, sha256)
- Extract: binary is at top level inside archive

### jq -- standalone binary (no archive)
- Tag prefix: `jq-` (tags like `jq-1.8.1`)
- Assets: `jq-linux-amd64`, `jq-linux-arm64` (raw binaries, no archive)
- Checksum: `sha256sum.txt`
- Format: `"binary"` -- no extraction needed

### uv -- multi-binary with per-asset checksums
- Tag prefix: `""` (no prefix, tags are just version numbers)
- Assets: `uv-x86_64-unknown-linux-gnu.tar.gz` with matching `.sha256` file
- Ships two binaries: `uv` and `uvx`
- extract_path is an array, checksum_asset is per-arch

### gh -- wildcard extract path
- Tags: `v2.88.1`, asset: `gh_2.88.1_linux_amd64.tar.gz`
- Archive has versioned top-level dir: `gh_2.88.1_linux_amd64/bin/gh`
- Uses wildcard extract_path `*/bin/gh` to handle version in directory name

### glab -- GitLab source
- Uses `"source": "gitlab"` and `"gitlab_project": "gitlab-org%2Fcli"`
- Downloads from GitLab API instead of GitHub
- No `repo` field

### codex -- pre-release
- Uses `"pre_release": true` because releases are alpha
- Tag prefix: `"rust-v"` (tags like `rust-v0.115.0-alpha.26`)
