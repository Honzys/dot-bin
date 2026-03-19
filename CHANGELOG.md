# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
