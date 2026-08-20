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

if [[ -d "$WORK_DIR" ]]; then
    echo "Removing previous build workspace..."
    sudo rm -rf "$WORK_DIR"
fi

mkdir -p "$OUT_DIR"

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
