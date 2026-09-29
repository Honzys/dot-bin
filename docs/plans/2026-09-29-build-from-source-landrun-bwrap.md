# Build-from-source packages: landrun + bubblewrap

## Why

herdr pi workers sandbox with landrun (Landlock) and bubblewrap. The Ubuntu 22.04 work
servers (gauss, higgs: glibc 2.35, kernel 5.15) have no nix, so both must come from dot-bin.
No usable prebuilt exists:

- landrun upstream binaries are cgo builds from an ubuntu-24.04 runner → need GLIBC_2.38
  (confirmed failing on gauss). A `CGO_ENABLED=0` build of v0.1.17 is fully static and works
  on gauss (with `--best-effort`, since 5.15 only has Landlock ABI v1).
- bubblewrap upstream ships only a source tarball. Third-party static builds are stale and
  unchecksummed; user chose to build from upstream.

## Changes

1. New package format `"build"` in `scripts/lib.sh`:
   - Package JSON keeps `repo`, `tag_prefix`, `channel` (version discovery via GitHub releases,
     unchanged), plus `"format": "build"` and `"build_script": "scripts/build/<name>.sh"`.
   - `architectures.{x86_64,arm64}` stay as objects (may be `{}`) so the per-arch loop and
     skip logic are unchanged.
   - In `download_and_install`, for `format == "build"`: skip download/checksum/extract and run
     `"$REPO_ROOT/<build_script>" <version> <arch> <out_dir>` where `<arch>` is `x86_64|arm64`
     and `<out_dir>` is `${BIN_DIR}/<arch>`. The script must place every `output_binaries`
     entry in `<out_dir>`, executable. Non-zero exit = arch failed (same accounting as today).
2. Build script contract (`scripts/build/<name>.sh`):
   - `set -euo pipefail`, shellcheck-clean, bash.
   - Builds inside Docker only (runners and dev box both have Docker; nothing else assumed —
     no Go/meson/cross toolchains on the host).
   - Output is a **fully static** ELF for the requested arch (no `GLIBC_` symbol versions,
     no `ld-linux` interpreter).
   - Both arches built from an x86_64 host **without QEMU/binfmt** (the dev box has no binfmt
     and we don't modify host kernel config). Cross-compile instead.
   - Source fetched from the official upstream at the exact tag (`v<version>`).
   - Bounded: no retry loops; Docker image tags pinned to a major line (e.g. `golang:1-alpine`,
     `alpine:3`, `debian:bookworm`).
   - Cleans up its temp dirs (trap).
3. `packages/landrun.json` (repo `Zouuup/landrun`, tag_prefix `v`, output `["landrun"]`) +
   `scripts/build/landrun.sh`: clone tag, `CGO_ENABLED=0 GOARCH=<amd64|arm64> go build
   -trimpath -ldflags="-s -w" ./cmd/landrun`.
4. `packages/bubblewrap.json` (repo `containers/bubblewrap`, tag_prefix `v`, output
   `["bwrap"]`) + `scripts/build/bubblewrap.sh`: static build of the upstream release tarball
   (`bubblewrap-<version>.tar.xz`), libcap linked statically, selinux/man/completions off.
5. Docs: CLAUDE.md package-format table + a "build" example; README package rows;
   `.claude/skills/add-package/SKILL.md` gets a short "build from source" note.
6. CI: `ci.yml` change detection also treats a changed `scripts/build/<name>.sh` as a changed
   package `<name>`. No QEMU steps.
7. CHANGELOG `0.9.0` (Added: landrun, bubblewrap; Changed: build-from-source format);
   versions.json via update.sh.

## Boundaries

- Don't touch existing package JSONs or the download/checksum paths for other formats.
- No new runtime deps for `install.sh`; the release tarball layout is unchanged.

## Acceptance

- `DOT_BIN_DIR=<tmp> ./scripts/update.sh landrun bubblewrap` → 2 updated, 0 failed.
- All four binaries: ELF, correct machine (x86-64 / aarch64), static (no GLIBC_, no ld-linux).
- `./scripts/update.sh jq` still works (regression check of the download path).
- shellcheck clean on changed scripts.
- On gauss (x86_64, 22.04): `landrun --best-effort` allows granted / denies ungranted paths;
  `bwrap --ro-bind / / --unshare-all -- id -u` succeeds.
