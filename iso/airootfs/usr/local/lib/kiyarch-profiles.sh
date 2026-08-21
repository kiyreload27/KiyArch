#!/usr/bin/env bash

# Profile manifests are data. This small reader deliberately has no shell
# fragments in the manifests and only reads the fields needed by the live
# planner/executor, so a profile cannot inject commands into either path.

kiyarch_profiles_init() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for candidate in /usr/local/share/kiyarch/profiles "$script_dir/../share/kiyarch/profiles"; do
        if [[ -d "$candidate" ]]; then
            KIYARCH_PROFILE_DIR="$candidate"
            break
        fi
    done
    [[ -n "${KIYARCH_PROFILE_DIR:-}" && -d "$KIYARCH_PROFILE_DIR" ]]
    KIYARCH_PROFILE_IDS=(minimal laptop desktop hyprland-caelestia custom)
}

kiyarch_profile_file() {
    local id="$1"
    [[ "$id" =~ ^(minimal|laptop|desktop|hyprland-caelestia|custom)$ ]] || return 1
    printf '%s/%s.json\n' "$KIYARCH_PROFILE_DIR" "$id"
}

kiyarch_profile_field() {
    local id="$1" field="$2" file
    file="$(kiyarch_profile_file "$id")" || return 1
    [[ -r "$file" ]] || return 1
    sed -nE 's/^[[:space:]]*"'"$field"'"[[:space:]]*:[[:space:]]*"([^"]*)"[,]?[[:space:]]*$/\1/p' "$file" | head -n1
}

kiyarch_profile_bool() {
    local id="$1" field="$2" file
    file="$(kiyarch_profile_file "$id")" || return 1
    sed -nE 's/^[[:space:]]*"'"$field"'"[[:space:]]*:[[:space:]]*(true|false)[,]?[[:space:]]*$/\1/p' "$file" | head -n1
}

kiyarch_profile_array() {
    local id="$1" field="$2" file line values value
    file="$(kiyarch_profile_file "$id")" || return 1
    line="$(grep -E '^[[:space:]]*"'"$field"'"[[:space:]]*:[[:space:]]*\[' "$file" | head -n1)"
    values="${line#*[}"
    values="${values%]*}"
    values="${values//\"/}"
    values="${values//,/ }"
    for value in $values; do
        [[ -n "$value" ]] && printf '%s\n' "$value"
    done
}

kiyarch_profile_hash() {
    local id="$1" file
    file="$(kiyarch_profile_file "$id")" || return 1
    # The declared hash covers the manifest payload with this field removed;
    # it is stable across ISO copies and is checked for shape below.
    kiyarch_profile_field "$id" manifest_hash
}

kiyarch_profile_source_repository() {
    local id="$1" file
    file="$(kiyarch_profile_file "$id")" || return 1
    sed -nE 's/.*"repository"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$file" | head -n1
}

kiyarch_profile_source_commit() {
    local id="$1" file
    file="$(kiyarch_profile_file "$id")" || return 1
    sed -nE 's/.*"commit"[[:space:]]*:[[:space:]]*"([0-9a-f]{40})".*/\1/p' "$file" | head -n1
}

kiyarch_profile_validate_manifest() {
    local id="$1" file required
    file="$(kiyarch_profile_file "$id")" || return 1
    [[ -s "$file" ]] || return 1
    for required in id display_name description manifest_version manifest_hash required_components optional_components packages services configuration_templates graphical_session; do
        grep -Eq '^[[:space:]]*"'"$required"'"[[:space:]]*:' "$file" || return 1
    done
    [[ "$(kiyarch_profile_field "$id" id)" == "$id" ]] || return 1
    [[ "$(kiyarch_profile_field "$id" manifest_version)" == 1 ]] || return 1
    [[ "$(kiyarch_profile_field "$id" manifest_hash)" =~ ^sha256:[0-9a-f]{64}$ ]] || return 1
    if command -v sha256sum >/dev/null 2>&1; then
        [[ "$(awk 'index($0, "manifest_hash") == 0' "$file" | sha256sum | awk '{print "sha256:" $1}')" == "$(kiyarch_profile_field "$id" manifest_hash)" ]] || return 1
    fi
}

kiyarch_package_name_valid() {
    [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9@+._:-]*$ ]] && [[ "$1" != *'/'* ]]
}

kiyarch_validate_package_list() {
    local package
    for package in "$@"; do
        kiyarch_package_name_valid "$package" || return 1
    done
}

kiyarch_profile_packages() {
    local id="$1" package
    while IFS= read -r package; do
        [[ -n "$package" ]] && printf '%s\n' "$package"
    done < <(kiyarch_profile_array "$id" packages)
}

kiyarch_unique_packages() {
    awk 'NF && !seen[$0]++'
}
