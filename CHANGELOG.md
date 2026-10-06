# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.13.0] - 2026-10-06

### Added

- msb (zerocore-ai/microsandbox) — microsandbox CLI, SHA256 verified. Built via
  `scripts/build/msb.sh` because msb needs the tarball's `libkrunfw.so.<ver>` beside
  it under that exact name; the library is installed next to `msb` in `bin/{arch}/`

## [0.12.0] - 2026-10-05

### Changed

- age: SHA256 verified against the GitHub release API asset `digest`; the install
  fails if the digest is missing or wrong
- New package option `checksum.github_digest` for releases without a checksum file

## [0.11.0] - 2026-10-05

### Added

- sops (getsops/sops) — encrypted secrets file editor, SHA256 verified
- age (FiloSottile/age) — file encryption, binaries `age` and `age-keygen`; no
  checksum verification (the release has no sha256 file, only Sigsum `.proof` files)

## [0.10.0] - 2026-10-05

### Added

- vault (HashiCorp Vault CLI) — secrets management CLI, from releases.hashicorp.com

### Changed

- New `"source": "hashicorp"` package type: latest version from checkpoint-api.hashicorp.com, assets and `SHA256SUMS` from releases.hashicorp.com

## [0.9.0] - 2026-09-29

### Added

- landrun (Zouuup/landrun) — Landlock sandbox runner, built from source (static, `CGO_ENABLED=0`)
- bubblewrap (containers/bubblewrap) — unprivileged sandboxing tool (`bwrap`), built from source (static)

### Changed

- New `"format": "build"` package type: runs `scripts/build/<name>.sh` in Docker to produce static binaries when upstream ships none usable on glibc 2.35 hosts

## [0.8.0] - 2026-09-28

### Added

- herdr (herdrdev/herdr) — terminal multiplexer for coding agents

## [0.7.0] - 2026-09-28

### Updated

- bw: 2026.2.0 → 2026.9.0
- gh: 2.88.1 → 2.101.0
- glab: 1.89.0 → 1.119.0
- glow: 2.1.1 → 3.0.0
- jq: 1.8.1 → 1.8.2
- k9s: 0.50.18 → 0.51.0
- kubectl: 1.35.2 → 1.37.1
- lazygit: 0.60.0 → 0.65.1
- nvim: 0.11.6 → 0.12.5
- pnpm: 10.32.1 → 12.8.1
- sesh: 2.24.2 → 2.31.0
- speedtest: 1.0.13 → 1.0.14
- tmux: 3.6a → 3.7c
- uv: 0.10.10 → 0.12.19
- zellij: 0.43.1 → 0.45.1
- zoxide: 0.9.9 → 0.10.0

### Removed

- codex (openai/codex) — agent harness, no longer distributed
- rtk (rtk-ai/rtk) — no longer distributed

### Fixed

- versions.json now tracks chezmoi 2.72.2, fd 10.5.0, fzf 0.74.4, git-lfs 3.8.0, ripgrep 15.2.0, trippy 0.13.0, xh 0.26.2

## [0.6.0] - 2026-05-25

### Added

- speedtest (librespeed/speedtest-cli) — network speed test CLI

### Fixed

- codex: updated asset patterns from `gnu` to `musl` (upstream change)
- pnpm: changed format from `binary` to `tarball` (upstream now ships `.tar.gz`)

### Changed

- Removed daily cron schedule from update workflow, now manual dispatch only

## [0.5.0] - 2026-04-10

### Added

- rtk (rtk-ai/rtk) — AI coding agent CLI
- git-lfs (git-lfs/git-lfs) — Git Large File Storage
- chezmoi (twpayne/chezmoi) — dotfile manager
- trippy (fujiapple852/trippy) — network diagnostic TUI (traceroute + ping)
- xh (ducaale/xh) — HTTP client (like curl/httpie)
- fd (sharkdp/fd) — modern find replacement
- ripgrep (BurntSushi/ripgrep) — fast grep (`rg`)
- fzf (junegunn/fzf) — fuzzy finder

### Fixed

- Daily update workflow: replaced manual git push + gh pr create with peter-evans/create-pull-request action to fix GITHUB_TOKEN permission failures on scheduled runs
- Checksum verification now handles binary-mode `*filename` format (used by git-lfs)

## [0.4.1] - 2026-03-19

### Added

- glow (charmbracelet/glow) — terminal markdown renderer
- kubectl (kubernetes/kubectl) — Kubernetes CLI

## [0.4.0] - 2026-03-16

### Added

- Release channel support: per-package `channel` field (`stable`/`unstable`)
- Environment variable override: `CHANNEL=unstable ./scripts/update.sh <pkg>`

### Changed

- Replaced `pre_release` boolean with `channel` field in package definitions
- Update output now shows the release channel being used

## [0.3.0] - 2026-03-16

### Changed

- Migrate from git-lfs to GitHub Releases for binary distribution
- CI now publishes `dot-bin-{arch}.tar.gz` release tarballs instead of committing binaries
- Add `install.sh` for `curl | bash` installation

## [0.2.0] - 2026-03-16

### Added

- Multi-architecture support (x86_64 + arm64) for all 15 packages
- Checksum verification for 7 packages (lazygit, jq, uv, gh, glab, k9s, sesh)
- Per-asset checksum support for uv and zellij-style packages
- `bin/x86_64/` and `bin/arm64/` directory structure

## [0.1.0] - 2026-03-16

### Added

- Initial release with 15 CLI tool packages
- Package definition format (JSON) with GitHub and GitLab source support
- Automated update scripts (`scripts/update.sh`, `scripts/lib.sh`)
- GitHub Actions workflow for daily automated updates
- Support for tarball, zip, and standalone binary formats
