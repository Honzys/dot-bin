#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

packages=("$@")

# If no args, update all packages
if [[ ${#packages[@]} -eq 0 ]]; then
    for pkg_file in "${REPO_ROOT}/packages/"*.json; do
        packages+=("$(jq -r '.name' "$pkg_file")")
    done
fi

updated=0
failed=0

for name in "${packages[@]}"; do
    pkg_file="${REPO_ROOT}/packages/${name}.json"

    if [[ ! -f "$pkg_file" ]]; then
        echo "WARNING: No package definition for '${name}', skipping" >&2
        continue
    fi

    current=$(get_current_version "$name")

    echo "Checking ${name}..."
    if ! tag=$(get_latest_tag "$pkg_file"); then
        echo "  WARNING: Failed to fetch latest release for ${name}" >&2
        failed=$((failed + 1))
        continue
    fi

    if [[ -z "$tag" || "$tag" == "null" ]]; then
        echo "  WARNING: Could not determine latest tag for ${name}" >&2
        failed=$((failed + 1))
        continue
    fi

    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    version=$(strip_prefix "$tag" "$tag_prefix")

    channel=$(jq -r '.channel // "stable"' "$pkg_file")
    channel="${CHANNEL:-$channel}"

    if [[ "$version" == "$current" ]]; then
        echo "  ${name}: already at ${version}"
        continue
    fi

    echo "  ${name} [${channel}]: ${current:-<none>} -> ${version} (archs: ${ARCHITECTURES[*]})"
    if download_and_install "$pkg_file" "$tag"; then
        echo "  ${name}: installed ${version}"
        updated=$((updated + 1))
    else
        echo "  ERROR: Failed to install ${name} ${version}" >&2
        failed=$((failed + 1))
    fi
done

echo ""
echo "Done. ${updated} package(s) updated, ${failed} failed."

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
