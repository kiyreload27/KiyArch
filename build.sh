#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$ROOT_DIR/iso"
WORK_DIR="$ROOT_DIR/work"
OUT_DIR="$ROOT_DIR/out"

VERSION="$(cat "$ROOT_DIR/VERSION")"

echo
echo "========================================"
echo "             KiyArch Builder"
echo "========================================"
echo
echo "Version:  $VERSION"
echo "Profile:  $PROFILE_DIR"
echo "Work:     $WORK_DIR"
echo "Output:   $OUT_DIR"
echo

echo "Validating KiyArch profile..."
"$ROOT_DIR/scripts/validate-profile.sh"

# Fail before deleting an existing workspace when the host is missing the
# Archiso toolchain. This keeps a failed dependency check non-destructive.
if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "ERROR: mkarchiso is not installed or not on PATH (install the Arch Linux archiso package)." >&2
    exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required to run mkarchiso and clean the build workspace." >&2
    exit 1
fi
# Validate credentials before removing the workspace. A failed sudo prompt
# must never leave the checkout with a partially cleaned build state.
if ! sudo -v; then
    echo "ERROR: sudo authorization is required to clean the workspace and build the ISO." >&2
    exit 1
fi

if [[ -d "$WORK_DIR" ]]; then
    echo "Removing previous build workspace..."
    sudo rm -rf "$WORK_DIR"
fi

mkdir -p "$OUT_DIR"

# mkarchiso refuses to overwrite an existing image. Remove only KiyArch ISO
# outputs in this dedicated directory after validation and sudo authorization.
mapfile -t previous_images < <(find "$OUT_DIR" -maxdepth 1 -type f -name 'KiyArch-*.iso' -print)
if ((${#previous_images[@]})); then
    echo "Removing previous KiyArch ISO output..."
    rm -f -- "${previous_images[@]}"
fi

echo
echo "Building KiyArch..."
echo

sudo mkarchiso \
    -v \
    -w "$WORK_DIR" \
    -o "$OUT_DIR" \
    "$PROFILE_DIR"

echo
echo "========================================"
echo "          KiyArch build complete"
echo "========================================"
echo

find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -exec ls -lh {} \;
