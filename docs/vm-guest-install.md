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
scp "${SSH_INSTALLER_OPTS[@]}" ~/nixos-config/scripts/vm-guest-install.sh root@<vm-ip>:/root/

# Back in the VM (over SSH now, so paste works):
bash /root/vm-guest-install.sh
```

> **`Too many authentication failures` when connecting to the installer?**
> The installer's root accepts a *password*, but your ssh client offers every
> key the 1Password agent holds first, and sshd cuts you off (`MaxAuthTries`)
> before it reaches password auth. Force password-only auth and ignore the
> agent. Define this once in the host shell and reuse it for `scp`/`ssh`/`nix
> copy` below:
>
> ```bash
> # A bash ARRAY — not a plain string. A string word-splits wrong and scp
> # fails with "keyword pubkeyauthentication extra arguments at end of line".
> SSH_INSTALLER_OPTS=(-o PubkeyAuthentication=no -o PreferredAuthentications=password -o IdentityAgent=none)
> ```
>
> This friction is installer-only. The *installed* `vm-guest` authorizes your
> key (baked into `modules/common.nix`), so `ssh todd@<vm-ip>` later just works.

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

## 4b. (Optional) Pre-seed the VM store from the host — fully offline install

A normal ONLINE install works fine given enough disk + swap (see Troubleshooting
below). Pre-seeding is only worth it if the VM's network is unreliable or you
want a zero-download install: copy the already-realised closure from the HOST
into the VM's target store.

Note: `herdr` and `zoom` are NOT in cache.nixos.org — they build from source in
the VM (herdr compiles libghostty-vt via Zig). Seeding from a host that already
has them built skips those builds entirely, which is the main reason to bother.

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
# NIX_SSHOPTS forces password auth so the 1Password agent's keys don't trip
# sshd's MaxAuthTries ("Too many authentication failures") — same options as
# SSH_INSTALLER_OPTS in the fast-path note above.
export NIX_SSHOPTS="-o PubkeyAuthentication=no -o PreferredAuthentications=password -o IdentityAgent=none"
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

## Troubleshooting — failures seen during a real install

These were all hit on a first install (8 GB RAM / originally 60 GB disk). The
scripts now handle them, but if you install by hand or on a smaller VM:

- **`Too many authentication failures`** connecting to the installer over SSH:
  the 1Password agent offers many keys before password auth. Force password-only:
  `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password -o IdentityAgent=none`.
  For `scp`, pass those as an ARRAY (`opts=(-o ...); scp "${opts[@]}" ...`) — a
  plain string word-splits wrong ("keyword pubkeyauthentication extra arguments").

- **`Can't lookup blockdev` on mount** right after `mkfs`: udev hasn't created
  `/dev/disk/by-label/*` yet. Run `udevadm settle` before mounting (or mount the
  device node, e.g. `/dev/vda2`, directly).

- **Duplicate `fileSystems."/boot"` in the generated hardware config**:
  `nixos-generate-config` sometimes appends a bogus `{ device = "/boot"; fsType
  = "none"; options = ["bind"]; }` after the real vfat entry. The duplicate key
  silently wins → unbootable. Delete the bind-mount block, keep the vfat one.

- **`Killed` mid-install** (no error, just "Killed"): OOM. 8 GB RAM isn't enough
  to build the closure. Add swap on the target: `fallocate -l 8G /mnt/swapfile;
  chmod 600 /mnt/swapfile; mkswap /mnt/swapfile; swapon /mnt/swapfile`.

- **`No space left on device`**: 60 GB is too small for the closure (~35 GB) +
  source builds (herdr/zoom Zig caches) + swap. Grow the disk live from the host
  (`virsh blockresize vm-guest --path <qcow2> --size 100G`), then in the VM
  `sgdisk -e /dev/vda; partprobe /dev/vda; parted /dev/vda -- resizepart 2 100%;
  resize2fs /dev/vda2`. The provision script now defaults to 100 GB.
