# KiyArch implementation audit

Updated after the Minimal UEFI/systemd-boot hardening pass. This document
keeps the important distinction between source validation, an installation
that completed, and a VM that genuinely booted from its installed disk.

## Support matrix

| Target | Current state |
|---|---|
| Minimal, UEFI, systemd-boot | Verified in disposable QEMU UEFI VM; installed-disk boot and reboot completed |
| Laptop | Static/profile data only |
| Desktop | Static/profile data only |
| Hyprland + Caelestia | Static/profile data only; source build and graphical login unverified |
| Custom | Planner/schema review only; base profile is now recorded |
| GRUB UEFI/BIOS | Deferred; branded configuration exists but is not advertised as production support |
| Legacy BIOS installation | Deferred and rejected by the executor |

## Root causes fixed in source

- The live root account uses zsh, so `.bash_profile` was not a reliable login
  hook. A tty1-only `/root/.zprofile` now launches `kiyarch-menu`, excludes
  SSH/non-tty sessions, and uses `exec` to avoid a relaunch loop. The menu's
  `q`/rescue path still opens a normal shell.
- `kiyarch-execute` defined `partition_devices` but did not call it before
  formatting. The call is now explicit after the final destructive
  confirmation.
- The executor previously used only `set -u`. It now uses
  `set -Eeuo pipefail` with an error trap and an unmistakable incomplete
  installation message.
- Partition types, block devices, filesystem types, mounts, pacstrap output,
  and fstab creation are checked after their operations.
- The previous boot setup wrote loader metadata under `/boot/loader` while the
  ESP was mounted at `/boot/efi`. The executor now uses the ESP's
  `/boot/efi/loader` tree, copies the kernel/initramfs to the ESP, invokes
  installed-root-aware `bootctl`, and requires both systemd-boot binaries,
  including `EFI/BOOT/BOOTX64.EFI`.
- Loader entries use the root filesystem UUID and never hardcode a `/dev/sdX`
  path.
- Sudo validation now targets the exact installed file with `visudo -c -f`;
  wildcard expansion is not used.
- Services are read from the selected manifest/base manifest and enabled in a
  generic loop. Minimal therefore enables only `NetworkManager.service`.
- Custom plans now record `base_profile` so future execution can reproduce the
  selected composition.
- The guided installer now moves directly from disk selection and a readable
  installation summary to the executor. The executor rechecks disk identity
  and uses one final `y/N` erase confirmation.

## Final validation now required before success

The executor reports eight validation stages covering the mounted root, ESP,
fstab, kernel/initramfs, systemd-boot, user/sudo configuration, declared
services, locale/hostname/NetworkManager, plus pinned Caelestia checks when
applicable. Failure stops execution and says not to reboot. A read-only helper
is available as:

```bash
kiyarch-diagnose --root /mnt --esp /mnt/boot/efi
```

It reports missing boot files, loader files, kernel/initramfs, fstab, UUID
resolution, and `bootctl` status without mounting or modifying anything.

## Verified versus not verified

Currently verified in this checkout:

- Minimal UEFI/systemd-boot installation completed in the disposable QEMU VM;
  the ISO was detached and the installed system booted successfully through a
  subsequent reboot;

- profile/manifests and manifest hashes;
- schema 1.1 plans and legacy schema 1.0 validator compatibility;
- disk-selection safety rejection tests;
- shell syntax for installer/menu/executor/diagnostic;
- tty1/SSH handoff checks;
- executor fail-fast, fallback-path, stable-root-ID, service, sudo, and fstab
  validation source checks.

Not yet honestly claimable:

- a fresh disposable VMware disk installed by the current ISO;
- GRUB boot;
- end-to-end Laptop, Desktop, Hyprland/Caelestia, or Custom profiles.

## Required next regression

Build a new ISO, boot a fresh UEFI VM with a known disposable virtual disk,
select Minimal, accept the final `y/N` erase confirmation, and inspect the
executor's eight validation lines. Power off, detach the ISO, boot the virtual
disk, then check:

```bash
lsblk
findmnt
systemctl --failed
bootctl status
systemctl status NetworkManager
id
sudo -v
reboot
```

Only after that VM has booted twice from its installed disk should the support
matrix mark Minimal as `Verified`.
