# dot-bin

Portable, version-controlled CLI toolchain. All binaries tracked via git-lfs with automated updates from upstream GitHub/GitLab releases.

## Usage

```bash
git clone <repo-url>
export PATH="$HOME/projects/dot-bin/bin:$PATH"
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
packages/   — per-package JSON definitions
scripts/    — update driver and shared library
bin/        — all binaries (git-lfs tracked)
```

## CI

GitHub Actions runs daily at 06:00 UTC to check for upstream updates. Can also be triggered manually with an optional package filter.
