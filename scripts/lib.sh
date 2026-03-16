#!/usr/bin/env bash
# Shared functions for dot-bin package management
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${REPO_ROOT}/bin"
VERSIONS_FILE="${REPO_ROOT}/versions.json"

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
    local source tag_prefix pre_release repo gitlab_project tag

    source=$(jq -r '.source // "github"' "$pkg_file")
    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    pre_release=$(jq -r '.pre_release // false' "$pkg_file")

    if [[ "$source" == "gitlab" ]]; then
        gitlab_project=$(jq -r '.gitlab_project' "$pkg_file")
        tag=$(curl -sS "https://gitlab.com/api/v4/projects/${gitlab_project}/releases" \
            | jq -r --arg prefix "$tag_prefix" \
                '[.[] | select(.tag_name | startswith($prefix))][0].tag_name')
    elif [[ "$pre_release" == "true" ]]; then
        repo=$(jq -r '.repo' "$pkg_file")
        tag=$(gh api "repos/${repo}/releases" --jq \
            "[.[] | select(.tag_name | startswith(\"${tag_prefix}\"))][0].tag_name")
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

    local source repo tag_prefix version asset_pattern asset_name gitlab_project

    source=$(jq -r '.source // "github"' "$pkg_file")
    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    version=$(strip_prefix "$tag" "$tag_prefix")
    asset_pattern=$(jq -r '.asset_pattern' "$pkg_file")
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
    else
        repo=$(jq -r '.repo' "$pkg_file")
        gh release download "$tag" --repo "$repo" --pattern "$asset_name" --dir "$dest_dir"
    fi

    echo "$asset_name"
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

    local format
    format=$(jq -r '.format' "$pkg_file")

    case "$format" in
        tarball)
            if ! tar -xzf "${tmpdir}/${asset_name}" -C "$tmpdir"; then
                echo "ERROR: Failed to extract ${asset_name}" >&2
                return 1
            fi
            if ! install_extracted "$pkg_file" "$tmpdir"; then
                return 1
            fi
            ;;
        zip)
            if ! unzip -qo "${tmpdir}/${asset_name}" -d "$tmpdir"; then
                echo "ERROR: Failed to extract ${asset_name}" >&2
                return 1
            fi
            if ! install_extracted "$pkg_file" "$tmpdir"; then
                return 1
            fi
            ;;
        binary)
            local bin_name
            bin_name=$(jq -r '.output_binaries[0]' "$pkg_file")
            mv "${tmpdir}/${asset_name}" "${BIN_DIR}/${bin_name}" || return 1
            chmod +x "${BIN_DIR}/${bin_name}" || return 1
            ;;
    esac
}

install_extracted() {
    local pkg_file="$1"
    local tmpdir="$2"

    local path_type
    path_type=$(jq -r '.extract_path | type' "$pkg_file")

    if [[ "$path_type" == "array" ]]; then
        local i=0
        while IFS= read -r extract_path; do
            local bin_name
            bin_name=$(jq -r --argjson i "$i" '.output_binaries[$i]' "$pkg_file")
            local resolved
            resolved=$(resolve_path "$tmpdir" "$extract_path")
            cp "$resolved" "${BIN_DIR}/${bin_name}"
            chmod +x "${BIN_DIR}/${bin_name}"
            i=$((i + 1))
        done < <(jq -r '.extract_path[]' "$pkg_file")
    else
        local extract_path bin_name resolved
        extract_path=$(jq -r '.extract_path' "$pkg_file")
        bin_name=$(jq -r '.output_binaries[0]' "$pkg_file")
        resolved=$(resolve_path "$tmpdir" "$extract_path")
        cp "$resolved" "${BIN_DIR}/${bin_name}"
        chmod +x "${BIN_DIR}/${bin_name}"
    fi
}

download_and_install() {
    local pkg_file="$1"
    local tag="$2"

    local name
    name=$(jq -r '.name' "$pkg_file")

    local tmpdir
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" RETURN

    local asset_name
    if ! asset_name=$(download_asset "$pkg_file" "$tag" "$tmpdir"); then
        return 1
    fi

    if ! install_binary "$pkg_file" "$tmpdir" "$asset_name"; then
        return 1
    fi

    local tag_prefix version
    tag_prefix=$(jq -r '.tag_prefix // ""' "$pkg_file")
    version=$(strip_prefix "$tag" "$tag_prefix")
    set_version "$name" "$version"
}
