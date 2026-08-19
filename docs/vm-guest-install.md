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

- ISO staged at `/var/lib/libvirt/images/nixos-minimal-vm-guest.iso` (NOT under
  `$HOME` — that's mode 700 on NixOS, so the libvirt qemu user can't read it):
  ```bash
  sudo mv ~/Downloads/nixos-minimal-vm-guest.iso /var/lib/libvirt/images/
  sudo chown qemu-libvirtd:qemu-libvirtd /var/lib/libvirt/images/nixos-minimal-vm-guest.iso 2>/dev/null || true
  ```
- libvirt running; `default` storage pool active
- The VM is created by `scripts/vm-guest-provision.sh` (UEFI/OVMF firmware,
  4 vCPU, 8 GB RAM, 60 GB qcow2, virtio disk/net, SPICE display)

## 1. Create + boot the VM (host)

```bash
bash ~/nixos-config/scripts/vm-guest-provision.sh
```

This defines and starts `vm-guest` and opens virt-viewer on the ISO boot. You
land at the NixOS installer root shell (`nixos@nixos`).

## Fast path: `scripts/vm-guest-install.sh`

Steps 2–6 below are automated by `scripts/vm-guest-install.sh`, which partitions
`/dev/vda`, generates the hardware config, and runs the offline install. Get an
SSH session into the installer first (SPICE clipboard doesn't work in the live
ISO, so drive it from your laptop), pre-seed the store, then run the script:

```bash
# In the VM installer console (type by hand):
sudo -i; passwd; systemctl start sshd; ip -4 addr show   # note 192.168.122.x

# On the HOST — seed packages + repo + script into the VM (see step 4b for the
# nix copy details), then:
scp ~/nixos-config/scripts/vm-guest-install.sh root@<vm-ip>:/root/

# Back in the VM (over SSH now, so paste works):
bash /root/vm-guest-install.sh
```

The manual steps below remain the reference for what the script does, or for a
one-off where you'd rather run each step yourself.

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

## 4b. (Recommended) Pre-seed the VM store from the host — avoids download failures

The earlier install attempt failed during the package **download** phase of
`nixos-install` (the flaky NAT link dropped mid-download; it surfaces as "failed
installing packages"). Nothing in the `vm-guest` closure actually builds from
source — it's ~all binary-cache substitutions — so the robust fix is to copy the
already-realised closure from the HOST instead of re-downloading it in the VM.

**On the HOST (this laptop), once:** realise the full closure locally so there's
something to copy (this is the only "download from the internet" step, and it
runs on the reliable host link, not in the VM):

```bash
nix build --no-link ~/nixos-config#nixosConfigurations.vm-guest.config.system.build.toplevel
```

**In the VM installer**, enable sshd and note the host bridge IP is
`192.168.122.1` (libvirt `default` NAT). Then from the HOST, copy the closure
into the VM's mounted target store over SSH:

```bash
# In the VM: set a temporary root password so the host can ssh in
passwd            # (installer root shell; pick anything, it's throwaway)
systemctl start sshd

# On the HOST: push the whole system closure into /mnt on the VM.
# Replace <vm-ip> with the guest's 192.168.122.x (run `ip -4 addr` in the VM).
HOST_STORE_PATH=$(nix path-info ~/nixos-config#nixosConfigurations.vm-guest.config.system.build.toplevel)
nix copy --to "ssh-ng://root@<vm-ip>?remote-store=local?root=/mnt" "$HOST_STORE_PATH"
```

After this, every store path `nixos-install` needs is already under `/mnt/nix`,
so the install does **zero downloads** and cannot fail the way it did before.

## 5. Install

```bash
# --option substituters "" forces install to use only what's already in the
# store (the paths copied in 4b). Drop that flag if you skipped 4b.
nixos-install --flake /mnt/etc/nixos-config#vm-guest --option substituters ""
# Set the root password when prompted.
```

If you skipped step 4b and want to just retry the online install, run it with
verbose logging so a failure shows the real cause instead of a generic message:

```bash
nixos-install --flake /mnt/etc/nixos-config#vm-guest --show-trace -v
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
