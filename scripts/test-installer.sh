#!/usr/bin/env bash

# Safe regression tests for the planner milestone. No test invokes a disk,
# filesystem, mount, or package-changing operation.
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT_DIR/iso/airootfs/usr/local/bin"
INSTALLER="$BIN_DIR/kiyarch-install"
VALIDATOR="$BIN_DIR/kiyarch-plan"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
ERRORS=0

error() { printf 'ERROR: %s\n' "$1" >&2; ERRORS=$((ERRORS + 1)); }
pass() { printf 'PASS: %s\n' "$1"; }

printf 'Testing KiyArch planner milestone...\n'

for script in "$BIN_DIR/kiyarch-hw" "$INSTALLER" "$VALIDATOR" "$BIN_DIR/kiyarch-menu" "$BIN_DIR/kiyarch-execute" "$BIN_DIR/kiyarch-diagnose" "$ROOT_DIR/scripts/qemu-minimal-test.sh" "$ROOT_DIR/iso/airootfs/usr/local/lib/kiyarch-hardware.sh"; do
    bash -n "$script" || error "Bash syntax failed: ${script#"$ROOT_DIR/"}"
done

if grep -Fq 'exec /usr/local/bin/kiyarch-menu' "$ROOT_DIR/iso/airootfs/root/.zprofile" && \
   grep -Fq '"/dev/tty1"' "$ROOT_DIR/iso/airootfs/root/.zprofile" && \
   grep -Fq 'SSH_CONNECTION' "$ROOT_DIR/iso/airootfs/root/.zprofile" && \
   grep -Fq 'SSH_TTY' "$ROOT_DIR/iso/airootfs/root/.zprofile"; then
    pass 'zsh tty1 handoff excludes SSH and non-tty sessions'
else
    error 'zsh tty1 handoff is incomplete'
fi

if grep -Fq 'set -Eeuo pipefail' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq "trap 'on_error" "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'partition_devices' "$BIN_DIR/kiyarch-execute"; then
    pass 'executor fail-fast and partition invocation'
else
    error 'executor fail-fast or partition invocation is missing'
fi

if grep -Fq '"base_profile"' "$INSTALLER" && grep -Fq 'PROFILE_APPLY_ID' "$BIN_DIR/kiyarch-execute"; then
    pass 'custom plan records and executor reads its base profile'
else
    error 'custom base profile composition is not preserved'
fi

if grep -Fq 'EFI/BOOT/BOOTX64.EFI' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'EFI/systemd/systemd-bootx64.efi' "$BIN_DIR/kiyarch-execute" && \
   ! grep -Eq 'root=/dev/(sd|vd|xvd|nvme)' "$BIN_DIR/kiyarch-execute"; then
    pass 'systemd-boot fallback and stable root identifier checks'
else
    error 'systemd-boot fallback or stable root identifier checks are missing'
fi

if grep -Fq 'kiyarch_profile_array "$PROFILE_APPLY_ID" services' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'visudo -c -f' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'findmnt --verify --tab-file' "$BIN_DIR/kiyarch-execute"; then
    pass 'manifest-driven services and safe installed-state validation'
else
    error 'generic service or installed-state validation is missing'
fi

if grep -Fq '/usr/lib/systemd/systemd' "$BIN_DIR/kiyarch-execute"; then
    pass 'pacstrap validation accepts Arch systemd filesystem layout'
else
    error 'pacstrap validation assumes the wrong systemd path'
fi

if grep -Fq 'useradd -m -U -G wheel' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq "stat -c '%u:%g'" "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'home_uid="$(arch-chroot' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'etc/skel/.zshrc' "$BIN_DIR/kiyarch-execute"; then
    pass 'installer creates users, validates installed IDs, and seeds zsh startup state'
else
    error 'installer user creation or ownership/startup validation is incomplete'
fi

if grep -Fq 'Package availability preflight passed' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'pacstrap -K "$ROOT_MOUNT"' "$BIN_DIR/kiyarch-execute" && \
   ! grep -Fq 'pacstrap -K -c' "$BIN_DIR/kiyarch-execute"; then
    pass 'package availability is preflighted and downloads use the target filesystem'
else
    error 'target-local package download handling is missing'
fi

if grep -Fq '[[ "$USER_SHELL" == fish ]] && REQUESTED_PACKAGES+=(fish)' "$INSTALLER"; then
    pass 'selected fish shell is added to the requested package set'
else
    error 'selected fish shell can be installed without its package'
fi

if grep -Fq 'build_effective_services' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq 'package_requested openssh' "$BIN_DIR/kiyarch-execute" && \
   grep -Fq '[[ "$GRAPHICAL" == true ]] && add_effective_service greetd.service' "$BIN_DIR/kiyarch-execute"; then
    pass 'custom profile services follow the effective session and package set'
else
    error 'custom profile service composition is incomplete'
fi

post_line="$(grep -n '^    post_validate$' "$BIN_DIR/kiyarch-execute" | tail -n1 | cut -d: -f1)"
success_line="$(grep -n 'Installation complete' "$BIN_DIR/kiyarch-execute" | tail -n1 | cut -d: -f1)"
if [[ "$post_line" =~ ^[0-9]+$ && "$success_line" =~ ^[0-9]+$ && "$post_line" -lt "$success_line" ]] && \
   grep -Fq 'KiyArch installation verified successfully.' "$BIN_DIR/kiyarch-execute"; then
    pass 'verified success is gated by final validation'
else
    error 'installer success is not visibly gated by final validation'
fi

if ! rg -n '(^|[;&|[:space:]])(mount|umount|parted|sgdisk|fdisk|wipefs|mkfs|pacstrap)([[:space:]]|$)' "$BIN_DIR/kiyarch-diagnose" >/dev/null; then
    pass 'installation diagnostic is read-only by source inspection'
else
    error 'installation diagnostic contains a state-changing command'
fi

if grep -Fq "bootmodes=('bios.syslinux'" "$ROOT_DIR/iso/profiledef.sh" && \
   grep -Fq "'uefi.systemd-boot'" "$ROOT_DIR/iso/profiledef.sh" && \
   ! grep -Fq "'uefi.grub'" "$ROOT_DIR/iso/profiledef.sh"; then
    pass 'Minimal boot scope is UEFI systemd-boot with BIOS live support'
else
    error 'active boot scope is broader than the verified milestone'
fi

if "$ROOT_DIR/scripts/validate-profile.sh" >/dev/null; then
    pass 'Archiso profile validation'
else
    error 'Archiso profile validation'
fi

INSTALLER_PATH="$INSTALLER" KIYARCH_INSTALL_LIBRARY_ONLY=1 bash -c '
    set --
    source "$INSTALLER_PATH"
    KIYARCH_ARCH=x86_64
    KIYARCH_FIRMWARE=uefi
    STORAGE_DEVICE=(/dev/vda)
    STORAGE_SIZE=("16 GiB")
    STORAGE_SIZE_BYTES=(17179869184)
    STORAGE_MODEL=("Test Disk")
    STORAGE_TRANSPORT=(virtio)
    STORAGE_CLASS=(virtio)
    STORAGE_MEDIA=(solid_state)
    STORAGE_REMOVABLE=(no)
    STORAGE_READONLY=(0)
    STORAGE_PTTYPE=(none)
    STORAGE_METADATA=(complete)
    SELECTED_INDEX=0
    ADMIN_USER=alice
    print_plan_json
' > "$TEST_DIR/plan.json"

if "$VALIDATOR" --validate "$TEST_DIR/plan.json" >/dev/null; then
    pass 'valid planner-only JSON plan'
else
    error 'valid planner-only JSON plan was rejected'
fi

sed 's/"schema_version":"1.1"/"schema_version":"1.0"/' "$TEST_DIR/plan.json" > "$TEST_DIR/legacy.json"
if "$VALIDATOR" --validate "$TEST_DIR/legacy.json" >/dev/null; then
    pass 'legacy schema 1.0 remains validator-readable'
else
    error 'legacy schema 1.0 plan was rejected'
fi

sed 's/"executor_enabled":false/"executor_enabled":true/' "$TEST_DIR/plan.json" > "$TEST_DIR/executor-enabled.json"
if "$VALIDATOR" --validate "$TEST_DIR/executor-enabled.json" >/dev/null 2>&1; then
    error 'validator accepted executor_enabled=true'
else
    pass 'validator rejects enabled executor'
fi

sed 's/"schema_version":"1.1"/"schema_version":"9.9"/' "$TEST_DIR/plan.json" > "$TEST_DIR/wrong-schema.json"
if "$VALIDATOR" --validate "$TEST_DIR/wrong-schema.json" >/dev/null 2>&1; then
    error 'validator accepted an unknown schema version'
else
    pass 'validator rejects unknown schema version'
fi

expect_selection_rejected() {
    local description="$1" setup="$2"
    if printf '1\n' | INSTALLER_PATH="$INSTALLER" SETUP="$setup" KIYARCH_INSTALL_LIBRARY_ONLY=1 bash -c '
        set --
        source "$INSTALLER_PATH"
        STORAGE_DEVICE=(/dev/test)
        STORAGE_SIZE=("16 GiB")
        STORAGE_SIZE_BYTES=(17179869184)
        STORAGE_MODEL=("Test Disk")
        STORAGE_TRANSPORT=(virtio)
        STORAGE_CLASS=(virtio)
        STORAGE_MEDIA=(solid_state)
        STORAGE_REMOVABLE=(no)
        STORAGE_READONLY=(0)
        STORAGE_PTTYPE=(none)
        STORAGE_METADATA=(complete)
        eval "$SETUP"
        select_disk
    ' >/dev/null 2>&1; then
        error "selection was accepted: $description"
    else
        pass "selection rejected: $description"
    fi
}

expect_selection_rejected 'read-only disk' 'STORAGE_READONLY=(1)'
expect_selection_rejected 'ambiguous metadata' 'STORAGE_METADATA=(ambiguous)'
expect_selection_rejected 'legacy MBR partition table' 'STORAGE_PTTYPE=(dos)'
expect_selection_rejected 'undersized disk' 'STORAGE_SIZE=(8 GiB); STORAGE_SIZE_BYTES=(8589934592)'

if rg -n '(^|[;&|[:space:]])(parted|sgdisk|fdisk|wipefs|mkfs|mount|pacstrap)([[:space:]]|$)' "$INSTALLER" >/dev/null; then
    error 'planner source contains a forbidden disk operation'
else
    pass 'planner command safety audit'
fi

if ((ERRORS)); then
    printf 'Planner tests failed with %d error(s).\n' "$ERRORS" >&2
    exit 1
fi
printf 'All planner tests passed.\n'
