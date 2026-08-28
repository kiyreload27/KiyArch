# KiyArch

KiyArch is a universal x86_64 Arch Linux live environment built with Archiso
and the official `releng` profile. It remains normal Arch Linux: the project
adds a small amount of branding, live-environment tooling, and future
installer work without creating a separate incompatible distribution.

## Goals

- Remain based on standard Arch Linux.
- Support desktop and laptop systems.
- Support Intel and AMD CPUs.
- Support Intel, AMD, NVIDIA, and hybrid graphics configurations.
- Detect hardware and recommend appropriate packages.
- Provide a guided and safe installation process.
- Install Hyprland and Caelestia as the default desktop environment.
- Keep hardware detection separate from installation profiles.
- Avoid unnecessary machine-specific assumptions.

## Current live environment

The current development ISO provides:

- the original **Midnight Forge** visual identity across the BIOS boot menu,
  GRUB menu, MOTD, tty1 menu, and installer headings; its palette, typography,
  composition, and voice are documented in `docs/IDENTITY.md`;
- the `kiyarch-help` command and KiyArch MOTD;
- the read-only `kiyarch-install` planner, which creates a validated JSON
  installation plan without executing any disk or package operation;
- the dependency-free `kiyarch-plan --validate` plan contract checker;
- read-only `kiyarch-hw` detection for system firmware/virtualization,
  manufacturer and form factor, Intel/AMD CPU microcode, Intel/AMD/NVIDIA and
  virtual graphics, networking, Bluetooth, laptop power devices, and physical
  storage targets;
- `kiyarch-hw --json`, with a stable top-level report containing `system`,
  `cpu`, `graphics`, `network`, `bluetooth`, `power`, `storage`, and
  `recommendations` objects;
- OpenSSH with `sshd.service` enabled at boot;
- `kiyarch-ssh` for service, port, LAN address, hostname, authentication, and
  authorized-key status.
- `kiyarch-diagnose` for a read-only report of an installed root, ESP,
  systemd-boot files, loader entry, fstab, UUID resolution, and bootctl state.

SSH uses public-key authentication by default. Root password authentication is
disabled, no password is created automatically, and the helper never prints
key contents. Put only trusted public keys in `/root/.ssh/authorized_keys`.

Hardware detection is advisory and intentionally does not install packages,
load unexpected modules, modify configuration, partition disks, or format
storage. NVIDIA driver selection is deferred until installation can inspect the
exact GPU and target setup. Removable disks are shown explicitly and require
future installer confirmation.

## Terminal installer and profiles

Run the planner from the live environment with:

```bash
kiyarch-install --export-plan /run/kiyarch/install-plan.json
```

The tty1 session opens a local-only KiyArch menu; SSH and manually opened
shells are unaffected. The planner always presents Minimal, Laptop, Desktop,
Hyprland + Caelestia, and Custom profiles. Profile manifests are versioned
JSON data under `iso/airootfs/usr/local/share/kiyarch/profiles`. The Hyprland +
Caelestia profile installs the Midnight Forge Hyprland, Kitty, Fuzzel, and
Caelestia presets plus an original KiyArch wallpaper.

The planner emits schema `1.1`, resolves packages from official Arch
repositories, verifies the pinned Caelestia source, and never changes a disk.
The local tty1 menu passes the validated plan directly to the separate
executor, which can also be invoked explicitly with
`kiyarch-execute --plan /run/kiyarch/install-plan.json` (or `--dry-run`). It
supports only UEFI/GPT, one 1 GiB FAT32 EFI partition, remaining ext4 root,
no swap, no encryption, NetworkManager, a named sudo user, and a locked root
password. It recollects disk identity, shows one final readable installation
summary, asks for a single `y/N` erase confirmation, and runs post-install
validation.

Support status is intentionally conservative: Minimal UEFI/systemd-boot is
now `Verified` after a disposable QEMU UEFI VM installed the system, booted
without the ISO, and completed a subsequent reboot. Laptop, Desktop,
Hyprland + Caelestia, and Custom remain `Static-tests-only`; GRUB is `Deferred`
and legacy BIOS installation is `Deferred`.

It lists device, size, model, transport, removable state, read-only state,
current partition-table metadata, and warnings before selection. Legacy BIOS,
missing disks, read-only disks, unsafe metadata, unsupported current partition
tables, and disks smaller than 16 GiB are rejected before any destructive
operation. The selected disk is re-scanned immediately before the plan is
written and again by the executor immediately before confirmation. Removable
media additionally require `I UNDERSTAND THIS IS REMOVABLE MEDIA`.

The output is versioned JSON with `schema_version: "1.1"` and these stable
sections: `source_hardware`, `target_disk`, `firmware_policy`,
`partition_layout`, `filesystem_policy`, `account_configuration`,
`desktop_profile`, `encryption`, `execution`, `warnings`, and
`unresolved_decisions`. The validator still reads 1.0 planner-only plans, but
the executor accepts only 1.1. Passwords, private keys, and other secrets are
never written to plans or logs.

Run the safe regression suite from the development checkout with:

```bash
scripts/test-installer.sh
```

For a disposable UEFI VM, native Windows users can use
`scripts/qemu-minimal-test.ps1` after installing QEMU. The first run boots the
ISO with a fresh qcow2 disk; stop QEMU after installation, then run it again
with `-Installed` to boot the disk without the ISO. The Bash equivalent is
available for Linux/WSL users as `scripts/qemu-minimal-test.sh`.

Validate an exported plan inside the live environment with:

```bash
kiyarch-plan --validate /run/kiyarch/install-plan.json
```

The validator uses only standard live-environment tools for policy checks. It
does not require a JSON package, and optionally performs a stricter syntax
check when `jq` or Perl JSON support is available.

## Build and validation

Run the profile validator directly:

```bash
scripts/validate-profile.sh
```

Build the ISO with:

```bash
./build.sh
```

`build.sh` validates the profile before invoking `mkarchiso`. It may remove the
local `work/` build directory and uses `sudo` for Archiso operations.

## Initial target

KiyArch 0.0.x focuses on:

- Archiso foundation
- KiyArch branding
- hardware detection
- networking
- installer framework
- safe disk selection
- reproducible ISO builds

The fixed-layout executor is implemented with explicit final validation, and
its Minimal UEFI disposable-VM regression has passed. This is not a claim of
compatibility with every physical desktop, laptop, GPU, or firmware
combination. Encryption, swap, Btrfs, LVM, RAID, multi-disk, BIOS
installation, AUR, arbitrary repositories, and custom layouts remain deferred.
