# KiyArch installation-plan schema

The planner emits UTF-8 JSON with `schema_version` `"1.1"`. The validator
continues to read legacy `"1.0"` planner-only plans for compatibility; the
destructive executor accepts only `1.1`.

Required 1.1 sections include:

```json
{
  "schema_version": "1.1",
  "plan_kind": "kiyarch_install_plan",
  "source_hardware": {},
  "target_disk": {},
  "firmware_policy": {},
  "partition_layout": {},
  "filesystem_policy": {},
  "install_profile": {
    "id": "minimal",
    "display_name": "Minimal",
    "manifest_version": "1",
    "manifest_hash": "sha256:...",
    "base_profile": "minimal",
    "components": [],
    "additional_packages": [],
    "package_source": "official_arch_repositories",
    "caelestia_source": null
  },
  "locale": "en_US.UTF-8",
  "keyboard_layout": "us",
  "timezone": "UTC",
  "hostname": "kiyarch",
  "network_policy": {},
  "account_policy": {},
  "session_policy": {},
  "requested_packages": [],
  "resolved_package_availability": {},
  "account_configuration": {},
  "desktop_profile": {},
  "encryption": {},
  "execution": {},
  "warnings": [],
  "unresolved_decisions": []
}
```

The fixed executor layout is UEFI/GPT, a 1 GiB FAT32 EFI System Partition,
remaining-space ext4 root, no swap, no encryption, NetworkManager, a named
sudo user, and a locked root password. Package input is limited to official
Arch repository names. The Hyprland + Caelestia profile records the upstream
repository and a full immutable commit; it never uses `curl | sh` or AUR.

Plans contain no passwords, private keys, tokens, or secret input. The
executor recollects device path, size, model, transport, media, partition
metadata, and available stable identifiers, then requires exact device/size
and destructive confirmations before any disk operation.

Validate with:

```bash
kiyarch-plan --validate /run/kiyarch/install-plan.json
```
