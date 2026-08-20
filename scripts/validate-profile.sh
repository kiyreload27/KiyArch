#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$ROOT_DIR/iso"
BIN_DIR="$PROFILE_DIR/airootfs/usr/local/bin"
PACKAGES_FILE="$PROFILE_DIR/packages.x86_64"
PROFILE_FILE="$PROFILE_DIR/profiledef.sh"
ERRORS=0

error() {
    printf 'ERROR: %s\n' "$1" >&2
    ERRORS=$((ERRORS + 1))
}

check_file() {
    if [[ ! -e "$1" ]]; then error "missing required file: ${1#"$ROOT_DIR"/}"; fi
}

printf 'Validating KiyArch Archiso profile...\n'
for required in \
    "$PROFILE_FILE" \
    "$PACKAGES_FILE" \
    "$PROFILE_DIR/pacman.conf" \
    "$PROFILE_DIR/grub/grub.cfg" \
    "$PROFILE_DIR/syslinux/syslinux.cfg" \
    "$PROFILE_DIR/efiboot/loader/loader.conf" \
    "$PROFILE_DIR/airootfs/etc/hostname" \
    "$PROFILE_DIR/airootfs/etc/passwd" \
    "$PROFILE_DIR/airootfs/etc/ssh/sshd_config.d/00-kiyarch-security.conf" \
    "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service" \
    "$BIN_DIR/kiyarch-help" \
    "$BIN_DIR/kiyarch-hw" \
    "$BIN_DIR/kiyarch-ssh"; do
    check_file "$required"
done

if [[ -L "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service" ]]; then
    [[ "$(readlink "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service")" == /usr/lib/systemd/system/sshd.service ]] || \
        error "sshd.service enablement symlink has an unexpected target"
else
    error "sshd.service enablement entry is not a symlink"
fi

for package in inetutils pciutils dmidecode openssh rfkill; do
    if ! awk -v wanted="$package" '$1 == wanted { found=1 } END { exit !found }' "$PACKAGES_FILE"; then
        error "required package is missing from packages.x86_64: $package"
    fi
done

mapfile -t duplicate_packages < <(awk 'NF && $1 !~ /^#/ { print $1 }' "$PACKAGES_FILE" | sort | uniq -d)
if ((${#duplicate_packages[@]})); then
    error "duplicate package entries: ${duplicate_packages[*]}"
fi

for executable in "$BIN_DIR"/*; do
    [[ -f "$executable" ]] || continue
    name="$(basename "$executable")"
    if [[ ! -x "$executable" ]]; then
        error "custom command is not executable in the source tree: $name"
    fi
    if ! grep -Fq "[\"/usr/local/bin/$name\"]=" "$PROFILE_FILE"; then
        error "custom executable has no file_permissions entry: $name"
    fi
    if ! bash -n "$executable"; then
        error "bash syntax check failed: $name"
    fi
done

if ! grep -Eq '^PermitRootLogin[[:space:]]+prohibit-password$' "$PROFILE_DIR/airootfs/etc/ssh/sshd_config.d/00-kiyarch-security.conf"; then
    error "secure PermitRootLogin setting is missing"
fi
if ! grep -Eq '^PasswordAuthentication[[:space:]]+no$' "$PROFILE_DIR/airootfs/etc/ssh/sshd_config.d/00-kiyarch-security.conf"; then
    error "password authentication is not explicitly disabled"
fi
if ! grep -Eq '^PubkeyAuthentication[[:space:]]+yes$' "$PROFILE_DIR/airootfs/etc/ssh/sshd_config.d/00-kiyarch-security.conf"; then
    error "pubkey authentication is not explicitly enabled"
fi

if ((ERRORS)); then
    printf 'Profile validation failed with %d error(s).\n' "$ERRORS" >&2
    exit 1
fi

printf 'Profile validation passed.\n'
