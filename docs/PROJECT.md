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

- the `kiyarch-help` command and KiyArch MOTD;
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

SSH uses public-key authentication by default. Root password authentication is
disabled, no password is created automatically, and the helper never prints
key contents. Put only trusted public keys in `/root/.ssh/authorized_keys`.

Hardware detection is advisory and intentionally does not install packages,
load unexpected modules, modify configuration, partition disks, or format
storage. NVIDIA driver selection is deferred until installation can inspect the
exact GPU and target setup. Removable disks are shown explicitly and require
future installer confirmation.

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

The installer itself will be developed only after the live ISO foundation is
verified. KiyArch is still in development: the installer, disk safety flow,
Hyprland/Caelestia setup, and broader physical-hardware testing are not yet
implemented. A successful builder-VM test is not a claim of compatibility with
every physical desktop, laptop, GPU, or firmware combination.
