#!/usr/bin/env bash
# Install msb (microsandbox CLI) from the upstream release tarball, which holds
# `msb` plus `libkrunfw.so.<ver>`. msb only finds libkrunfw beside itself under
# that exact versioned name, and <ver> changes between releases, so both files
# are copied as-is (static extract_path/output_binaries can't express that).
# The tarball is verified against the release's checksums.sha256.
#
# Usage: msb.sh <version> <x86_64|arm64> <out_dir>
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
    echo "usage: $0 <version> <x86_64|arm64> <out_dir>" >&2
    exit 1
fi

version="$1"
arch="$2"
out_dir="$3"

case "$arch" in
    x86_64) upstream_arch="x86_64" ;;
    arm64) upstream_arch="aarch64" ;;
    *) echo "ERROR: unsupported architecture '${arch}'" >&2; exit 1 ;;
esac

tarball="microsandbox-linux-${upstream_arch}.tar.gz"
base_url="https://github.com/zerocore-ai/microsandbox/releases/download/v${version}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL -o "${tmpdir}/${tarball}" "${base_url}/${tarball}"
curl -fsSL -o "${tmpdir}/checksums.sha256" "${base_url}/checksums.sha256"

expected="$(awk -v f="$tarball" '$2 == f || $2 == "*" f { print $1 }' "${tmpdir}/checksums.sha256")"
if [[ -z "$expected" ]]; then
    echo "ERROR: ${tarball} not listed in checksums.sha256" >&2
    exit 1
fi
actual="$(sha256sum "${tmpdir}/${tarball}" | awk '{ print $1 }')"
if [[ "$expected" != "$actual" ]]; then
    echo "ERROR: sha256 mismatch for ${tarball}: expected ${expected}, got ${actual}" >&2
    exit 1
fi

mkdir "${tmpdir}/x"
tar --no-same-owner -C "${tmpdir}/x" -xzf "${tmpdir}/${tarball}"

shopt -s nullglob
libs=("${tmpdir}"/x/libkrunfw.so.*)
if [[ ! -f "${tmpdir}/x/msb" || "${#libs[@]}" -ne 1 ]]; then
    echo "ERROR: expected msb and exactly one libkrunfw.so.* in ${tarball}" >&2
    exit 1
fi

# Drop libkrunfw from an older release so a stale version can't shadow the new one.
mkdir -p "$out_dir"
rm -f "${out_dir}"/libkrunfw.so.*
install -m 0755 "${tmpdir}/x/msb" "${out_dir}/msb"
install -m 0755 "${libs[0]}" "${out_dir}/$(basename "${libs[0]}")"
