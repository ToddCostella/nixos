# Installing `vm-guest` as a persistent libvirt VM

A real, installed NixOS VM running the full nixos-dev desktop + tool set,
managed permanently in virt-manager. Unlike `nixos-rebuild build-vm --flake
.#vm-test` (throwaway), this partitions a real virtual disk and installs the
`vm-guest` flake host onto it.

## What `vm-guest` is

`hosts/vm-guest/configuration.nix` imports the SHARED
`hosts/nixos-dev/desktop-tools.nix` (GNOME, all dev tools, 1Password, fonts,
DE specialisations) plus `modules/common.nix` and home-manager — the same tools
as the laptop — but swaps the Dell physical tuning for VM-appropriate settings
(UEFI systemd-boot, virtio, SPICE guest agent, public DNS, no hugepages/EPP/
touchscreen/bluetooth).

## 0. Prerequisites (on the host, already done by setup)

- ISO staged at `~/Downloads/nixos-minimal-vm-guest.iso`
- libvirt running; `default` storage pool active
- The VM is created by `scripts/vm-guest-provision.sh` (UEFI/OVMF firmware,
  4 vCPU, 8 GB RAM, 60 GB qcow2, virtio disk/net, SPICE display)

## 1. Create + boot the VM (host)

```bash
bash ~/nixos-config/scripts/vm-guest-provision.sh
```

This defines and starts `vm-guest` and opens virt-viewer on the ISO boot. You
land at the NixOS installer root shell (`nixos@nixos`).

## 2. Partition the disk (in the VM console)

The VM disk is `/dev/vda`. Create a UEFI layout with labels the placeholder
hardware-config expects (`ESP`, `nixos`):

```bash
sudo -i
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart ESP fat32 1MiB 1GiB
parted /dev/vda -- set 1 esp on
parted /dev/vda -- mkpart primary 1GiB 100%

mkfs.fat -F 32 -n ESP /dev/vda1
mkfs.ext4 -L nixos /dev/vda2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/ESP /mnt/boot
```

## 3. Get the flake into the VM

The installer has git + nix (flakes enabled). Clone your repo (adjust remote if
private — you may need to auth, or copy via `scp`/a shared folder):

```bash
nix-shell -p git --run 'git clone https://github.com/ToddCostella/nixos.git /mnt/etc/nixos-config'
# or, if private: clone over SSH, or scp from the host.
```

## 4. Generate the real hardware config

```bash
nixos-generate-config --root /mnt
# This writes /mnt/etc/nixos/hardware-configuration.nix with the REAL vda UUIDs.
# Copy it over the placeholder in the flake:
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos-config/hosts/vm-guest/hardware-configuration.nix
```

Then in that generated file confirm the fileSystems point at
`/dev/disk/by-label/nixos` and `.../ESP` (or by-uuid — either works; if it used
UUIDs, that's fine and more precise). Commit is not required for a local
`nixos-install`, but the file must be tracked by git for the flake to see it:

```bash
cd /mnt/etc/nixos-config
git add hosts/vm-guest/hardware-configuration.nix
```

## 5. Install

```bash
nixos-install --flake /mnt/etc/nixos-config#vm-guest
# Set the root password when prompted.
```

`todd` has no password in the config (same as the laptop). After first boot,
log in via a TTY as root and run `passwd todd`, or set it now:

```bash
nixos-enter --root /mnt -c 'passwd todd'
```

## 6. Reboot into the installed system

```bash
reboot
```

Remove the ISO from the VM's CDROM (virt-manager → vm-guest → details → remove
CDROM, or it will offer to boot the installer again). You now have a permanent
GNOME VM with your full toolset.

## Post-install notes

- **1Password / secrets**: git signing, AWS creds, and `~/.secrets.env` need the
  1Password app authenticated inside the VM. Launch 1Password, sign in, enable
  the SSH agent + CLI integration, then `refresh-secrets`. Until then those
  features are inert (they do not block boot or login).
- **Clipboard / resize**: SPICE guest agent is enabled, so virt-manager clipboard
  sharing and display auto-resize work once you're in GNOME.
- **Updating the VM later**: `sudo nixos-rebuild switch --flake
  /etc/nixos-config#vm-guest` from inside the VM (pull the repo first).
