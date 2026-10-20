# mosh-server package (static build from source)

Goal: Jan's phone (Moshi app) connects to gauss with mosh, without root on gauss.
gauss gets dot-bin through the chezmoi hook `run_after_install-dotbin.sh`, so a
dot-bin release puts `mosh-server` in `~/.local/bin` there.

## Changes

- `packages/mosh.json`: `repo` `mobile-shell/mosh`, `tag_prefix` `mosh-`,
  `format` `build`, `build_script` `scripts/build/mosh.sh`,
  `output_binaries` `["mosh-server"]`. Same shape as `packages/bubblewrap.json`.
- `scripts/build/mosh.sh <version> <arch> <out_dir>`: same interface and style as
  `scripts/build/bubblewrap.sh`.
  - Download `mosh-<version>.tar.gz` from the GitHub release.
  - Verify a pinned SHA-256 per version. Unknown version = exit 1, so an upstream
    update needs a person to add the new hash. 1.4.0:
    `872e4b134e5df29c8933dff12350785054d2fd2839b5ae6b5587b14db1465ddd`
    (equal to `mosh_1.4.0.orig.tar.gz` in Debian's signed `mosh_1.4.0-1.dsc`).
  - Build a fully static `mosh-server` in Docker (Alpine/musl is the suggestion,
    any image that gives a static binary is fine). No utempter.
  - Only `mosh-server`. The client side is Moshi on the phone.
- Architectures: `x86_64` required. `arm64` only if it works without QEMU, as in
  bubblewrap.sh; else leave `arm64` out of the JSON and say why in a comment line of
  the build script.
- `README.md` package table row; `CHANGELOG.md` new `## [0.14.0] - 2026-10-20` with
  `### Added`, in the style of earlier entries.

## Boundaries

- Do not change `scripts/lib.sh`, `install.sh`, or workflows unless the build cannot
  work without it. If so, stop and report.
- Do not touch `versions.json` by hand.

## Acceptance

1. `DOT_BIN_DIR=<tmp>/bin ./scripts/update.sh mosh` exits 0 and writes
   `<tmp>/bin/x86_64/mosh-server`.
2. `file` reports a statically linked x86-64 ELF.
3. In plain `ubuntu:24.04` (no extra packages), with `LANG=en_US.UTF-8`:
   `mosh-server --version` prints 1.4.0, and `mosh-server new -p 60001` prints
   `MOSH CONNECT 60001 <key>`.
4. A changed hash in the script makes the build fail before compiling.
