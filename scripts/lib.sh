#!/usr/bin/env bash
# Shared functions for dot-bin package management
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${DOT_BIN_DIR:-${REPO_ROOT}/bin}"
VERSIONS_FILE="${REPO_ROOT}/versions.json"
ARCHITECTURES=("x86_64" "arm64")

get_current_version() {
    local name="$1"
    jq -r --arg name "$name" '.[$name] // ""' "$VERSIONS_FILE"
}

set_version() {
    local name="$1"
    local version="$2"
    local tmp
    tmp=$(mktemp)
    jq --arg name "$name" --arg ver "$version" '.[$name] = $ver' "$VERSIONS_FILE" > "$tmp"
    mv "$tmp" "$VERSIONS_FILE"
}

strip_prefix() {
    local tag="$1"
    local prefix="$2"
    echo "${tag#"$prefix"}"
}

get_latest_tag() {
    local pkg_file="$1"
    local source tag_prefix channel repo gitlab_project tag

    source=$(jq -r '.source // "github"' "$pkg_file")
    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    channel=$(jq -r '.channel // "stable"' "$pkg_file")

    # Allow CHANNEL env var to override per-package setting
    channel="${CHANNEL:-$channel}"

    if [[ "$source" == "gitlab" ]]; then
        gitlab_project=$(jq -r '.gitlab_project' "$pkg_file")
        if [[ "$channel" == "unstable" ]]; then
            tag=$(curl -sS "https://gitlab.com/api/v4/projects/${gitlab_project}/releases" \
                | jq -r --arg prefix "$tag_prefix" \
                    '[.[] | select(.tag_name | startswith($prefix))][0].tag_name')
        else
            # Stable: filter out pre-releases (upcoming_release flag)
            tag=$(curl -sS "https://gitlab.com/api/v4/projects/${gitlab_project}/releases" \
                | jq -r --arg prefix "$tag_prefix" \
                    '[.[] | select(.tag_name | startswith($prefix)) | select(.upcoming_release != true)][0].tag_name')
        fi
    elif [[ "$source" == "kubernetes" ]]; then
        tag=$(curl -sSL "https://dl.k8s.io/release/stable.txt")
    elif [[ "$channel" == "unstable" ]]; then
        repo=$(jq -r '.repo' "$pkg_file")
        tag=$(gh api "repos/${repo}/releases" --jq \
            "[.[] | select(.tag_name | startswith(\"${tag_prefix}\"))][0].tag_name")
    elif [[ -n "$tag_prefix" ]]; then
        # Stable with tag_prefix: filter by prefix and exclude pre-releases
        # (repos like bitwarden/clients publish multiple products with different prefixes)
        repo=$(jq -r '.repo' "$pkg_file")
        tag=$(gh api "repos/${repo}/releases" --jq \
            "[.[] | select(.tag_name | startswith(\"${tag_prefix}\")) | select(.prerelease == false)][0].tag_name")
    else
        repo=$(jq -r '.repo' "$pkg_file")
        tag=$(gh api "repos/${repo}/releases/latest" --jq '.tag_name')
    fi

    echo "$tag"
}

download_asset() {
    local pkg_file="$1"
    local tag="$2"
    local dest_dir="$3"
    local arch="$4"

    local source repo tag_prefix version asset_pattern asset_name gitlab_project

    source=$(jq -r '.source // "github"' "$pkg_file")
    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    version=$(strip_prefix "$tag" "$tag_prefix")
    asset_pattern=$(jq -r --arg arch "$arch" '.architectures[$arch].asset_pattern' "$pkg_file")

    if [[ -z "$asset_pattern" || "$asset_pattern" == "null" ]]; then
        echo "SKIP: No ${arch} asset defined" >&2
        return 2
    fi

    asset_name="${asset_pattern//\{version\}/$version}"

    if [[ "$source" == "gitlab" ]]; then
        gitlab_project=$(jq -r '.gitlab_project' "$pkg_file")
        local download_url
        download_url=$(curl -sS "https://gitlab.com/api/v4/projects/${gitlab_project}/releases/${tag}" \
            | jq -r --arg name "$asset_name" \
                '.assets.links[] | select(.name == $name) | .direct_asset_url')

        if [[ -z "$download_url" || "$download_url" == "null" ]]; then
            echo "ERROR: Could not find asset '${asset_name}' for ${tag}" >&2
            return 1
        fi

        curl -sSL -o "${dest_dir}/${asset_name}" "$download_url"
    elif [[ "$source" == "kubernetes" ]]; then
        local k8s_arch download_url
        case "$arch" in
            x86_64) k8s_arch="amd64" ;;
            arm64)  k8s_arch="arm64" ;;
            *)      echo "ERROR: Unsupported architecture '${arch}' for kubernetes source" >&2; return 1 ;;
        esac
        download_url="https://dl.k8s.io/release/${tag}/bin/linux/${k8s_arch}/${asset_name}"
        curl -sSL -o "${dest_dir}/${asset_name}" "$download_url"
    else
        repo=$(jq -r '.repo' "$pkg_file")
        gh release download "$tag" --repo "$repo" --pattern "$asset_name" --dir "$dest_dir"
    fi

    echo "$asset_name"
}

# Downloads a checksum file from the release, checking arch-specific override first
download_checksum_file() {
    local pkg_file="$1"
    local tag="$2"
    local dest_dir="$3"
    local arch="$4"

    local source checksum_asset tag_prefix version checksum_name

    source=$(jq -r '.source // "github"' "$pkg_file")
    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    version=$(strip_prefix "$tag" "$tag_prefix")

    # Check for arch-specific checksum asset, fall back to top-level
    checksum_asset=$(jq -r --arg arch "$arch" \
        '.architectures[$arch].checksum_asset // .checksum.asset' "$pkg_file")
    checksum_name="${checksum_asset//\{version\}/$version}"

    if [[ "$source" == "gitlab" ]]; then
        local gitlab_project download_url
        gitlab_project=$(jq -r '.gitlab_project' "$pkg_file")
        download_url=$(curl -sS "https://gitlab.com/api/v4/projects/${gitlab_project}/releases/${tag}" \
            | jq -r --arg name "$checksum_name" \
                '.assets.links[] | select(.name == $name) | .direct_asset_url')

        if [[ -z "$download_url" || "$download_url" == "null" ]]; then
            echo "ERROR: Could not find checksum asset '${checksum_name}' for ${tag}" >&2
            return 1
        fi

        curl -sSL -o "${dest_dir}/${checksum_name}" "$download_url"
    elif [[ "$source" == "kubernetes" ]]; then
        local k8s_arch download_url
        case "$arch" in
            x86_64) k8s_arch="amd64" ;;
            arm64)  k8s_arch="arm64" ;;
            *)      echo "ERROR: Unsupported architecture '${arch}' for kubernetes source" >&2; return 1 ;;
        esac
        download_url="https://dl.k8s.io/release/${tag}/bin/linux/${k8s_arch}/${checksum_name}"
        if ! curl -sSL -o "${dest_dir}/${checksum_name}" "$download_url"; then
            echo "ERROR: Failed to download checksum file '${checksum_name}'" >&2
            return 1
        fi
    else
        local repo
        repo=$(jq -r '.repo' "$pkg_file")
        if ! gh release download "$tag" --repo "$repo" --pattern "$checksum_name" --dir "$dest_dir"; then
            echo "ERROR: Failed to download checksum file '${checksum_name}'" >&2
            return 1
        fi
    fi

    echo "${dest_dir}/${checksum_name}"
}

verify_checksum() {
    local pkg_file="$1"
    local asset_name="$2"
    local asset_path="$3"
    local tag="$4"
    local arch="$5"

    local has_checksum
    has_checksum=$(jq -r '.checksum // empty' "$pkg_file")

    if [[ -z "$has_checksum" ]]; then
        echo "    INFO: No checksum configured, skipping verification" >&2
        return 0
    fi

    local algorithm checksum_file_path
    algorithm=$(jq -r '.checksum.algorithm' "$pkg_file")

    local tmpdir
    tmpdir=$(dirname "$asset_path")

    if ! checksum_file_path=$(download_checksum_file "$pkg_file" "$tag" "$tmpdir" "$arch"); then
        echo "    ERROR: Failed to download checksum file" >&2
        return 1
    fi

    # Extract expected hash — handles GNU format: "<hash>  <filename>" or "<hash> <filename>"
    local expected_hash
    expected_hash=$(awk -v name="$asset_name" '$NF == name {print $1; exit}' "$checksum_file_path")

    if [[ -z "$expected_hash" ]]; then
        # Per-asset checksum files may have a single entry with a different path
        local line_count
        line_count=$(wc -l < "$checksum_file_path")
        if [[ "$line_count" -le 1 ]]; then
            expected_hash=$(awk '{print $1}' "$checksum_file_path" | head -1)
        fi
    fi

    if [[ -z "$expected_hash" ]]; then
        echo "    ERROR: Could not find checksum for '${asset_name}' in checksum file" >&2
        return 1
    fi

    local actual_hash
    case "$algorithm" in
        sha256)
            actual_hash=$(sha256sum "$asset_path" | awk '{print $1}')
            ;;
        sha512)
            actual_hash=$(sha512sum "$asset_path" | awk '{print $1}')
            ;;
        *)
            echo "    ERROR: Unsupported checksum algorithm '${algorithm}'" >&2
            return 1
            ;;
    esac

    if [[ "$actual_hash" != "$expected_hash" ]]; then
        echo "    ERROR: Checksum mismatch for ${asset_name}" >&2
        echo "      Expected: ${expected_hash}" >&2
        echo "      Actual:   ${actual_hash}" >&2
        return 1
    fi

    echo "    Checksum verified (${algorithm})" >&2
    return 0
}

resolve_path() {
    local base_dir="$1"
    local pattern="$2"
    local match

    # Try exact path first
    if [[ -f "${base_dir}/${pattern}" ]]; then
        echo "${base_dir}/${pattern}"
        return
    fi

    # Glob expansion for wildcard paths
    # shellcheck disable=SC2086
    match=$(find "$base_dir" -path "${base_dir}/${pattern}" -print -quit 2>/dev/null || true)
    if [[ -n "$match" ]]; then
        echo "$match"
        return
    fi

    echo "ERROR: Could not find '${pattern}' in ${base_dir}" >&2
    return 1
}

install_binary() {
    local pkg_file="$1"
    local tmpdir="$2"
    local asset_name="$3"
    local arch="$4"

    local format arch_bin_dir
    format=$(jq -r '.format' "$pkg_file")
    arch_bin_dir="${BIN_DIR}/${arch}"
    mkdir -p "$arch_bin_dir"

    case "$format" in
        tarball)
            if ! tar -xzf "${tmpdir}/${asset_name}" -C "$tmpdir"; then
                echo "ERROR: Failed to extract ${asset_name}" >&2
                return 1
            fi
            if ! install_extracted "$pkg_file" "$tmpdir" "$arch"; then
                return 1
            fi
            ;;
        zip)
            if ! unzip -qo "${tmpdir}/${asset_name}" -d "$tmpdir"; then
                echo "ERROR: Failed to extract ${asset_name}" >&2
                return 1
            fi
            if ! install_extracted "$pkg_file" "$tmpdir" "$arch"; then
                return 1
            fi
            ;;
        binary)
            local bin_name
            bin_name=$(jq -r '.output_binaries[0]' "$pkg_file")
            mv "${tmpdir}/${asset_name}" "${arch_bin_dir}/${bin_name}" || return 1
            chmod +x "${arch_bin_dir}/${bin_name}" || return 1
            ;;
    esac
}

install_extracted() {
    local pkg_file="$1"
    local tmpdir="$2"
    local arch="$3"

    local arch_bin_dir path_type
    arch_bin_dir="${BIN_DIR}/${arch}"
    path_type=$(jq -r --arg arch "$arch" '.architectures[$arch].extract_path | type' "$pkg_file")

    if [[ "$path_type" == "array" ]]; then
        local i=0
        while IFS= read -r extract_path; do
            local bin_name
            bin_name=$(jq -r --argjson i "$i" '.output_binaries[$i]' "$pkg_file")
            local resolved
            resolved=$(resolve_path "$tmpdir" "$extract_path")
            cp "$resolved" "${arch_bin_dir}/${bin_name}"
            chmod +x "${arch_bin_dir}/${bin_name}"
            i=$((i + 1))
        done < <(jq -r --arg arch "$arch" '.architectures[$arch].extract_path[]' "$pkg_file")
    else
        local extract_path bin_name resolved
        extract_path=$(jq -r --arg arch "$arch" '.architectures[$arch].extract_path' "$pkg_file")
        bin_name=$(jq -r '.output_binaries[0]' "$pkg_file")
        resolved=$(resolve_path "$tmpdir" "$extract_path")
        cp "$resolved" "${arch_bin_dir}/${bin_name}"
        chmod +x "${arch_bin_dir}/${bin_name}"
    fi
}

download_and_install() {
    local pkg_file="$1"
    local tag="$2"

    local name arch_success
    name=$(jq -r '.name' "$pkg_file")
    arch_success=0

    for arch in "${ARCHITECTURES[@]}"; do
        local arch_def
        arch_def=$(jq -r --arg arch "$arch" '.architectures[$arch] // "null"' "$pkg_file")
        if [[ "$arch_def" == "null" ]]; then
            echo "    [${arch}] skipped (no definition)"
            continue
        fi

        local tmpdir
        tmpdir=$(mktemp -d)

        echo "    [${arch}] downloading..."
        local asset_name download_rc=0
        asset_name=$(download_asset "$pkg_file" "$tag" "$tmpdir" "$arch") || download_rc=$?

        if [[ "$download_rc" -eq 2 ]]; then
            echo "    [${arch}] skipped (no asset pattern)"
            rm -rf "$tmpdir"
            continue
        elif [[ "$download_rc" -ne 0 ]]; then
            echo "    [${arch}] ERROR: download failed" >&2
            rm -rf "$tmpdir"
            continue
        fi

        if ! verify_checksum "$pkg_file" "$asset_name" "${tmpdir}/${asset_name}" "$tag" "$arch"; then
            echo "    [${arch}] ERROR: checksum verification failed, aborting" >&2
            rm -rf "$tmpdir"
            continue
        fi

        if install_binary "$pkg_file" "$tmpdir" "$asset_name" "$arch"; then
            echo "    [${arch}] installed"
            arch_success=$((arch_success + 1))
        else
            echo "    [${arch}] ERROR: install failed" >&2
        fi

        rm -rf "$tmpdir"
    done

    if [[ "$arch_success" -eq 0 ]]; then
        return 1
    fi

    local tag_prefix version
    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    version=$(strip_prefix "$tag" "$tag_prefix")
    set_version "$name" "$version"
}
