# dot-bin

Portable CLI toolchain with automated updates from upstream GitHub/GitLab releases. Binaries are published as GitHub Release tarballs — no git-lfs, no bloated clones.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Honzys/dot-bin/master/install.sh | bash
```

This detects your architecture, downloads the latest release tarball, verifies the SHA256 checksum, and extracts binaries to `~/.local/bin/`.

To install to a custom directory:

```bash
DOT_BIN_INSTALL_DIR=/opt/bin bash install.sh
```

Re-run the same command to update.

## Release Channels

Each package can be configured with a release channel in its JSON definition:

- **stable** (default): only considers non-pre-release versions
- **unstable**: includes pre-releases when checking for the latest version

Override the channel at runtime with the `CHANNEL` environment variable:

```bash
CHANNEL=unstable ./scripts/update.sh nvim   # get pre-release nvim
CHANNEL=stable ./scripts/update.sh codex    # get stable codex even though JSON says unstable
```

## Packages

| Package | Source | Description |
|---------|--------|-------------|
| nvim | neovim/neovim | Neovim text editor |
| lazygit | jesseduffield/lazygit | Terminal UI for git |
| jq | jqlang/jq | JSON processor |
| fnm | Schniz/fnm | Fast Node Manager |
| uv | astral-sh/uv | Python package manager (uv + uvx) |
| gh | cli/cli | GitHub CLI |
| glab | gitlab-org/cli | GitLab CLI |
| k9s | derailed/k9s | Kubernetes TUI |
| sesh | joshmedeski/sesh | Terminal session manager |
| zellij | zellij-org/zellij | Terminal multiplexer |
| zoxide | ajeetdsouza/zoxide | Smarter cd |
| bw | bitwarden/clients | Bitwarden CLI |
| tmux | tmux/tmux-builds | Terminal multiplexer |
| pnpm | pnpm/pnpm | Node package manager |
| codex | openai/codex | OpenAI Codex CLI |
| kubectl | kubernetes/kubectl | Kubernetes CLI |
| glow | charmbracelet/glow | Terminal markdown renderer |

## Local Development

The update scripts still work locally for development/testing:

```bash
./scripts/update.sh              # update all packages
./scripts/update.sh nvim lazygit # update specific packages
```

Binaries go to `bin/` (gitignored). Override with `DOT_BIN_DIR`:

```bash
DOT_BIN_DIR=/tmp/test/bin ./scripts/update.sh jq
```

## Structure

```
packages/        — per-package JSON definitions
scripts/         — update driver and shared library
install.sh       — user-facing install/update script
versions.json    — current versions (auto-generated)
```

## CI

GitHub Actions runs daily at 06:00 UTC. For each upstream update:

1. Downloads new binaries to a staging directory
2. Creates `dot-bin-{arch}.tar.gz` tarballs (x86_64 + arm64)
3. Publishes a date-tagged GitHub Release with tarballs + checksums
4. Commits only `versions.json` to the repo
