#!/usr/bin/env bash
set -Eeuo pipefail

# Disposable QEMU/OVMF runner for the Minimal UEFI regression. It does not
# modify host disks; the only writable disk target is the explicitly selected
# qcow2 file.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_PATH="$ROOT_DIR/out/KiyArch-0.0.1-x86_64.iso"
DISK_PATH="$ROOT_DIR/.qemu/kiyarch-minimal.qcow2"
VARS_PATH="$ROOT_DIR/.qemu/kiyarch-minimal-vars.fd"
CUSTOM_DISK=false
# Keep the default modest so the VM is usable on an 8 GiB host.
MEMORY=2048
CPUS=2
INSTALLED_ONLY=false
RESET=false

usage() {
    cat <<'USAGE'
Usage:
  scripts/qemu-minimal-test.sh [--memory MiB] [--iso PATH] [--disk PATH]
  scripts/qemu-minimal-test.sh --installed [--memory MiB] [--disk PATH]
  scripts/qemu-minimal-test.sh --reset [--memory MiB] [--iso PATH] [--disk PATH]

The default mode boots a fresh disposable 30 GiB qcow2 disk with the ISO.
After installation, stop QEMU and run with --installed to boot the disk
without the ISO. --reset only removes the script's explicitly selected qcow2
disk and UEFI variable file before recreating them.
USAGE
}

while (($#)); do
    case "$1" in
        --memory) (($# >= 2)) || { usage >&2; exit 2; }; MEMORY=$2; shift 2 ;;
        --iso) (($# >= 2)) || { usage >&2; exit 2; }; ISO_PATH=$2; shift 2 ;;
        --disk) (($# >= 2)) || { usage >&2; exit 2; }; DISK_PATH=$2; CUSTOM_DISK=true; shift 2 ;;
        --installed) INSTALLED_ONLY=true; shift ;;
        --reset) RESET=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

# Keep each explicitly selected disposable disk paired with its own UEFI
# variable store. Sharing the default store can leak boot entries between
# independent regression runs.
if [[ "$CUSTOM_DISK" == true ]]; then
    if [[ "$DISK_PATH" == *.qcow2 ]]; then
        VARS_PATH="${DISK_PATH%.qcow2}.vars.fd"
    else
        VARS_PATH="${DISK_PATH}.vars.fd"
    fi
fi

command -v qemu-system-x86_64 >/dev/null || { printf 'qemu-system-x86_64 is required\n' >&2; exit 1; }
command -v qemu-img >/dev/null || { printf 'qemu-img is required\n' >&2; exit 1; }
CODE_FIRMWARE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
VARS_TEMPLATE=/usr/share/edk2/x64/OVMF_VARS.4m.fd
[[ -r "$CODE_FIRMWARE" && -r "$VARS_TEMPLATE" ]] || { printf 'OVMF firmware files are unavailable\n' >&2; exit 1; }

if [[ "$RESET" == true ]]; then
    [[ "$DISK_PATH" == "$ROOT_DIR/.qemu/"* ]] || { printf -- '--reset is restricted to the repository .qemu directory\n' >&2; exit 1; }
    rm -f -- "$DISK_PATH" "$VARS_PATH"
fi

mkdir -p -- "$(dirname "$DISK_PATH")" "$(dirname "$VARS_PATH")"
if [[ ! -e "$DISK_PATH" ]]; then
    qemu-img create -f qcow2 "$DISK_PATH" 30G
else
    printf 'Using existing disposable disk: %s\n' "$DISK_PATH"
fi
if [[ ! -e "$VARS_PATH" ]]; then
    cp -- "$VARS_TEMPLATE" "$VARS_PATH"
fi

if [[ "$INSTALLED_ONLY" != true ]]; then
    [[ -r "$ISO_PATH" ]] || { printf 'ISO not found: %s\nBuild it with: sudo ./build.sh\n' "$ISO_PATH" >&2; exit 1; }
fi

QEMU_ARGS=(
    -name KiyArch-Minimal-UEFI
    -machine q35
    # Explicitly disable QEMU audio input/output, including microphone capture.
    -audiodev driver=none,id=noaudio
    -m "$MEMORY"
    -smp "$CPUS"
    -drive "if=pflash,format=raw,readonly=on,file=$CODE_FIRMWARE"
    -drive "if=pflash,format=raw,file=$VARS_PATH"
    -drive "if=virtio,format=qcow2,file=$DISK_PATH"
    -nic user,model=virtio-net-pci
)

if [[ "$INSTALLED_ONLY" != true ]]; then
    QEMU_ARGS+=( -drive "media=cdrom,readonly=on,format=raw,file=$ISO_PATH" -boot order=d )
fi

if [[ -e /dev/kvm ]]; then
    QEMU_ARGS+=( -enable-kvm -cpu host )
    printf 'QEMU mode: KVM acceleration\n'
else
    QEMU_ARGS+=( -cpu max )
    printf 'QEMU mode: software emulation (/dev/kvm unavailable)\n'
fi

printf 'Disk: %s\nUEFI variables: %s\n' "$DISK_PATH" "$VARS_PATH"
printf 'Stop QEMU, then rerun with --installed to boot without the ISO.\n'
exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
