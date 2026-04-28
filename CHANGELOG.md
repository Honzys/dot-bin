# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.5.1] - 2026-04-28

### Updated

- bw: 2026.2.0 → 2026.4.1
- codex: 0.115.0-alpha.26 → 0.125.0
- gh: 2.88.1 → 2.91.0
- glab: 1.89.0 → 1.93.0
- glow: 2.1.1 → 2.1.2
- kubectl: 1.35.2 → 1.36.0
- lazygit: 0.60.0 → 0.61.1
- nvim: 0.11.6 → 0.12.2
- pnpm: 10.32.1 → 10.33.2
- sesh: 2.24.2 → 2.26.1
- uv: 0.10.10 → 0.11.8
- zellij: 0.43.1 → 0.44.1

### Added

- rtk 0.37.2

## [0.5.0] - 2026-04-10

### Added

- rtk (rtk-ai/rtk) — AI coding agent CLI

### Fixed

- Daily update workflow: replaced manual git push + gh pr create with peter-evans/create-pull-request action to fix GITHUB_TOKEN permission failures on scheduled runs

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
