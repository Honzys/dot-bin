#!/usr/bin/env bash
# Build a fully static bwrap binary from the upstream bubblewrap release
# tarball, for the requested architecture, using Docker (no QEMU/binfmt:
# arm64 is cross-compiled from an x86_64 debian:bookworm container).
#
# Usage: bubblewrap.sh <version> <x86_64|arm64> <out_dir>
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <version> <x86_64|arm64> <out_dir>" >&2
  exit 1
fi

version="$1"
arch="$2"
out_dir="$3"

case "$arch" in
x86_64 | arm64) ;;
*)
  echo "unsupported arch: $arch (expected x86_64 or arm64)" >&2
  exit 1
  ;;
esac

image="debian:bookworm"
tarball="bubblewrap-${version}.tar.xz"
url="https://github.com/containers/bubblewrap/releases/download/v${version}/${tarball}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL -o "${tmpdir}/${tarball}" "$url"
tar -C "$tmpdir" -xf "${tmpdir}/${tarball}"

# Cross-compilation file for arm64; unused (but harmless) for x86_64.
cat >"${tmpdir}/cross.ini" <<'EOF'
[binaries]
c = 'aarch64-linux-gnu-gcc'
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
pkgconfig = 'pkg-config'

[properties]
pkg_config_libdir = '/usr/lib/aarch64-linux-gnu/pkgconfig'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

# In-container build: installs the toolchain for the requested arch, then
# configures a fully static meson build (selinux/man/completions/tests off).
cat >"${tmpdir}/build-in-container.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
arch="$1"

# Fix ownership of everything under the bind mount even on failure, so the
# host-side trap can always remove its tmpdir.
trap 'chown -R "$(stat -c %u:%g /work)" /work' EXIT

apt-get update -qq
apt-get install -y -qq --no-install-recommends meson ninja-build pkg-config gcc

meson_args=()
case "$arch" in
x86_64)
  apt-get install -y -qq --no-install-recommends libc6-dev libcap-dev
  ;;
arm64)
  dpkg --add-architecture arm64
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    gcc-aarch64-linux-gnu libc6-dev-arm64-cross libcap-dev:arm64
  meson_args=(--cross-file /work/cross.ini)
  ;;
esac

src_dir="$(find /work -mindepth 1 -maxdepth 1 -type d -name 'bubblewrap-*')"
cd "$src_dir"
meson setup /work/build "${meson_args[@]}" \
  --buildtype=release --prefer-static -Dc_link_args=-static \
  -Dselinux=disabled -Dman=disabled \
  -Dbash_completion=disabled -Dzsh_completion=disabled -Dtests=false
ninja -C /work/build bwrap
EOF
chmod +x "${tmpdir}/build-in-container.sh"

docker run --rm -v "${tmpdir}:/work" -w /work "$image" \
  bash /work/build-in-container.sh "$arch"

mkdir -p "$out_dir"
install -m 0755 "${tmpdir}/build/bwrap" "${out_dir}/bwrap"
