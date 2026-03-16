# dot-bin

Portable, version-controlled CLI toolchain. All binaries tracked via git-lfs with automated updates from upstream GitHub/GitLab releases.

## Usage

```bash
git clone <repo-url>
ARCH=$(uname -m | sed 's/aarch64/arm64/')
export PATH="$HOME/projects/dot-bin/bin/${ARCH}:$PATH"
```

## Updating

```bash
./scripts/update.sh              # update all packages
./scripts/update.sh nvim lazygit # update specific packages
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

## Structure

```
packages/        — per-package JSON definitions
scripts/         — update driver and shared library
bin/x86_64/      — x86_64 binaries (git-lfs tracked)
bin/arm64/       — arm64 binaries (git-lfs tracked)
versions.json    — current versions (auto-generated)
```

## CI

GitHub Actions runs daily at 06:00 UTC to check for upstream updates. Can also be triggered manually with an optional package filter.
