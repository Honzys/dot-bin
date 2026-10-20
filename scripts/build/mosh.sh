#!/usr/bin/env bash
# Build a fully static mosh-server from the upstream mosh release tarball
# using Docker (alpine/musl). Only mosh-server: the client is Moshi on the phone.
# The tarball SHA-256 is pinned per version; a new upstream version needs a
# person to verify and add its hash below.
# arm64 is not built: it would need QEMU/binfmt (Alpine has no cross toolchain
# for it here), so packages/mosh.json lists x86_64 only.
#
# Usage: mosh.sh <version> <x86_64> <out_dir>
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
    echo "usage: $0 <version> <x86_64> <out_dir>" >&2
    exit 1
fi

version="$1"
arch="$2"
out_dir="$3"

case "$arch" in
    x86_64) ;;
    *) echo "ERROR: unsupported architecture '${arch}'" >&2; exit 1 ;;
esac

case "$version" in
    1.4.0) sha256="872e4b134e5df29c8933dff12350785054d2fd2839b5ae6b5587b14db1465ddd" ;;
    *) echo "ERROR: no pinned SHA-256 for mosh ${version}; verify it and add it to $0" >&2; exit 1 ;;
esac

# Alpine 3.17 on purpose: its protobuf 3.21 ships static libs and needs no abseil;
# later Alpine releases ship protobuf (and abseil) as shared libraries only.
image="alpine:3.17"
tarball="mosh-${version}.tar.gz"
url="https://github.com/mobile-shell/mosh/releases/download/mosh-${version}/${tarball}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL -o "${tmpdir}/${tarball}" "$url"
echo "${sha256}  ${tmpdir}/${tarball}" | sha256sum -c - >&2
tar -C "$tmpdir" --no-same-owner -xzf "${tmpdir}/${tarball}"

# In-container build: static mosh-server only, no utempter, no client.
cat >"${tmpdir}/build-in-container.sh" <<'INNER'
#!/bin/sh
set -eu

# Fix ownership of everything under the bind mount even on failure, so the
# host-side trap can always remove its tmpdir.
trap 'chown -R "$(stat -c %u:%g /work)" /work' EXIT

apk add --no-cache build-base pkgconf perl protobuf-dev protoc \
  ncurses-dev ncurses-static openssl-dev openssl-libs-static zlib-dev zlib-static

cd /work/mosh-*/
./configure --disable-client --disable-examples --without-utempter \
  LDFLAGS=-static
# top-level make: it generates the VERSION file that version.h depends on
make -j"$(nproc)"
strip src/frontend/mosh-server
INNER

docker run --rm -v "${tmpdir}:/work" -w /work "$image" \
  sh /work/build-in-container.sh

mkdir -p "$out_dir"
install -m 0755 "${tmpdir}/mosh-${version}/src/frontend/mosh-server" "${out_dir}/mosh-server"
