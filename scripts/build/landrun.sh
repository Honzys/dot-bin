#!/usr/bin/env bash
# Builds landrun from source: fully static, cross-compiled, no cgo/QEMU needed.
# Usage: landrun.sh <version> <x86_64|arm64> <out_dir>
set -euo pipefail

REPO_URL="https://github.com/Zouuup/landrun.git"
GO_IMAGE="golang:1-alpine"

version="$1"
arch="$2"
out_dir="$3"

case "$arch" in
    x86_64) goarch="amd64" ;;
    arm64)  goarch="arm64" ;;
    *)      echo "ERROR: unsupported architecture '${arch}'" >&2; exit 1 ;;
esac

workdir=$(mktemp -d)
# The Go module cache is written read-only; chmod before rm so cleanup can't fail.
trap 'chmod -R u+w "$workdir" 2>/dev/null || true; rm -rf "$workdir"' EXIT

git clone --depth 1 --branch "v${version}" "$REPO_URL" "${workdir}/src"
mkdir -p "${workdir}/gocache" "${workdir}/gopath"

docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "${workdir}/src:/src" \
    -v "${workdir}/gocache:/gocache" \
    -v "${workdir}/gopath:/gopath" \
    -w /src \
    -e HOME=/tmp \
    -e GOCACHE=/gocache \
    -e GOPATH=/gopath \
    -e CGO_ENABLED=0 \
    -e GOOS=linux \
    -e GOARCH="$goarch" \
    "$GO_IMAGE" \
    go build -trimpath -ldflags="-s -w" -o /src/landrun ./cmd/landrun

mkdir -p "$out_dir"
cp "${workdir}/src/landrun" "${out_dir}/landrun"
chmod +x "${out_dir}/landrun"
