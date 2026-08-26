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
    "$BIN_DIR/kiyarch-install" \
    "$BIN_DIR/kiyarch-execute" \
    "$BIN_DIR/kiyarch-plan" \
    "$BIN_DIR/kiyarch-ssh" \
    "$BIN_DIR/kiyarch-menu" \
    "$BIN_DIR/kiyarch-network" \
    "$BIN_DIR/kiyarch-diagnose" \
    "$PROFILE_DIR/airootfs/usr/local/lib/kiyarch-hardware.sh" \
    "$PROFILE_DIR/airootfs/usr/local/lib/kiyarch-profiles.sh" \
    "$PROFILE_DIR/airootfs/usr/local/lib/kiyarch-ui.sh" \
    "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/midnight-forge/wallpaper.png" \
    "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/midnight-forge/hypr/hyprland.conf" \
    "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/midnight-forge/hypr/hyprpaper.conf" \
    "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/midnight-forge/kitty/kitty.conf" \
    "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/midnight-forge/fuzzel/fuzzel.ini" \
    "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/midnight-forge/caelestia/shell.json" \
    "$PROFILE_DIR/airootfs/root/.bash_profile" \
    "$PROFILE_DIR/airootfs/root/.zprofile"; do
    check_file "$required"
done

if ! grep -Fq '["/usr/local/lib/kiyarch-ui.sh"]="0:0:644"' "$PROFILE_FILE"; then
    error "Midnight Forge UI library has no explicit ISO ownership/permission entry"
fi
if ! grep -Fq 'MIDNIGHT FORGE' "$PROFILE_DIR/airootfs/usr/local/lib/kiyarch-ui.sh"; then
    error "Midnight Forge console identity is missing"
fi

if ! grep -Fq 'exec /usr/local/bin/kiyarch-menu' "$PROFILE_DIR/airootfs/root/.zprofile"; then
    error "zsh login profile does not hand tty1 to kiyarch-menu"
fi
if ! grep -Fq 'SSH_CONNECTION' "$PROFILE_DIR/airootfs/root/.zprofile" || ! grep -Fq 'SSH_TTY' "$PROFILE_DIR/airootfs/root/.zprofile"; then
    error "zsh login profile lacks SSH exclusions"
fi
if ! grep -Fq 'tty 2>/dev/null' "$PROFILE_DIR/airootfs/root/.zprofile"; then
    error "zsh login profile does not restrict the menu to a terminal"
fi
if ! grep -Fq '["/root/.zprofile"]="0:0:644"' "$PROFILE_FILE"; then
    error "zsh login profile has no explicit ISO ownership/permission entry"
fi
if ! grep -Eq '^root:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:/usr/bin/zsh$' "$PROFILE_DIR/airootfs/etc/passwd"; then
    error "live root shell is no longer the expected zsh shell"
fi

if [[ -L "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service" ]]; then
    [[ "$(readlink "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service")" == /usr/lib/systemd/system/sshd.service ]] ||
        error "sshd.service enablement symlink has an unexpected target"
else
    error "sshd.service enablement entry is not a symlink"
fi

for package in inetutils pciutils dmidecode openssh rfkill networkmanager git cmake ninja; do
    if ! awk -v wanted="$package" '$1 == wanted { found=1 } END { exit !found }' "$PACKAGES_FILE"; then
        error "required package is missing from packages.x86_64: $package"
    fi
done

mapfile -t profile_manifests < <(find "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/profiles" -maxdepth 1 -type f -name '*.json' | sort)
if ((${#profile_manifests[@]} != 5)); then
    error "expected five profile manifests, found ${#profile_manifests[@]}"
fi
for manifest in "${profile_manifests[@]}"; do
    for field in id display_name description manifest_version manifest_hash required_components optional_components packages services configuration_templates graphical_session; do
        grep -Eq "^[[:space:]]*\"$field\"[[:space:]]*:" "$manifest" || error "profile manifest lacks $field: ${manifest##*/}"
    done
    grep -Eq '"manifest_version"[[:space:]]*:[[:space:]]*"1"' "$manifest" || error "profile manifest version is not 1: ${manifest##*/}"
    grep -Eq '"manifest_hash"[[:space:]]*:[[:space:]]*"sha256:[0-9a-f]{64}"' "$manifest" || error "profile manifest hash is invalid: ${manifest##*/}"
    declared_hash="$(sed -nE 's/^[[:space:]]*"manifest_hash"[[:space:]]*:[[:space:]]*"(sha256:[0-9a-f]{64})"[,]?[[:space:]]*$/\1/p' "$manifest" | head -n1)"
    actual_hash="$(awk 'index($0, "manifest_hash") == 0' "$manifest" | sha256sum | awk '{print "sha256:" $1}')"
    [[ "$declared_hash" == "$actual_hash" ]] || error "profile manifest hash does not match its payload: ${manifest##*/}"
done

for package in hyprland hyprpaper kitty fuzzel quickshell; do
    grep -Eq "\"$package\"" "$PROFILE_DIR/airootfs/usr/local/share/kiyarch/profiles/hyprland-caelestia.json" ||
        error "Midnight Forge desktop package is missing from Hyprland + Caelestia profile: $package"
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
