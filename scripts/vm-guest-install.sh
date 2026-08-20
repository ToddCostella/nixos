#!/usr/bin/env bash
# NixOS installation script for vm-guest (persistent libvirt/QEMU VM).
# Run as root INSIDE the NixOS minimal installer ISO, after the VM has been
# created by scripts/vm-guest-provision.sh (host side).
#
# Recommended workflow (avoids the download-phase failure — see
# docs/vm-guest-install.md):
#   1. Host:  bash scripts/vm-guest-provision.sh          # create + boot the VM
#   2. VM:    passwd; systemctl start sshd; ip -4 addr    # enable ssh, get IP
#   3. Host:  scp this repo + `nix copy` the closure to the VM (see step 4b in
#             the doc), then scp this script over
#   4. VM:    bash vm-guest-install.sh                    # <-- you are here
#
# The VM's single virtio disk is /dev/vda. This WIPES it.

set -euo pipefail

DISK="/dev/vda"
# Where the flake lives inside the installer. Point this at the repo you either
# git-cloned or scp'd in. Override with:  REPO_DIR=/path bash vm-guest-install.sh
REPO_DIR="${REPO_DIR:-/mnt/etc/nixos-config}"
# Default: install ONLINE from cache.nixos.org (proven to work with adequate
# disk + swap). Set SEEDED=1 only if you pre-copied the closure from the host
# (nix copy --to ...root=/mnt) and want a fully offline install.
SEEDED="${SEEDED:-0}"

# --- Guards -----------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo -i)." >&2; exit 1; }
[ -b "$DISK" ] || { echo "$DISK is not a block device — is this the VM?" >&2; exit 1; }
# Refuse to run on a real machine: the VM disk is virtio (vda). Bail if absent.
[ -e /dev/vda ] || { echo "No /dev/vda — this doesn't look like the vm-guest VM." >&2; exit 1; }

echo "==> Target disk:"
lsblk -d -o NAME,SIZE,MODEL "$DISK"
echo ""
read -rp "This will WIPE $DISK and install vm-guest. Type 'yes' to continue: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

# --- Clean any previous attempt ---------------------------------------------
echo "==> Cleaning previous install state"
umount /mnt/boot 2>/dev/null || true
umount /mnt 2>/dev/null || true
wipefs -a "$DISK" || true
sgdisk --zap-all "$DISK" || true
partprobe 2>/dev/null || true
sleep 2

# --- Partition (UEFI: ESP + root) -------------------------------------------
echo "==> Partitioning $DISK (UEFI: ESP + ext4 root)"
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart primary 1GiB 100%

echo "==> Formatting"
mkfs.fat -F 32 -n ESP "${DISK}1"
mkfs.ext4 -L nixos -F "${DISK}2"

echo "==> Mounting"
# Wait for udev to create the /dev/disk/by-label/* symlinks — mkfs writes the
# label but the symlink appears asynchronously, so an immediate mount races and
# fails with "Can't lookup blockdev".
udevadm settle
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/ESP /mnt/boot

# --- Flake presence ---------------------------------------------------------
if [ ! -f "$REPO_DIR/flake.nix" ]; then
  echo "No flake at $REPO_DIR." >&2
  echo "Clone or scp the repo there first, e.g.:" >&2
  echo "  nix-shell -p git --run 'git clone <repo> $REPO_DIR'" >&2
  echo "  # or from the host:  scp -r ~/nixos-config root@<vm-ip>:$REPO_DIR" >&2
  exit 1
fi

# --- Hardware config (generated live, real vda UUIDs) -----------------------
echo "==> Generating hardware configuration"
nixos-generate-config --root /mnt
# nixos-generate-config sometimes emits a SECOND, bogus fileSystems."/boot"
# bind-mount ({ device = "/boot"; fsType = "none"; ... }) after the real vfat
# entry. Two attrs with the same key make the bind-mount silently win, producing
# an unbootable system. Strip that block if present.
python3 - <<'PY' 2>/dev/null || true
import re, sys
p = "/mnt/etc/nixos/hardware-configuration.nix"
s = open(p).read()
s = re.sub(r'\n\s*fileSystems\."/boot" =\s*\{\s*device = "/boot";.*?\};', '', s, flags=re.S)
open(p, "w").write(s)
PY
cp /mnt/etc/nixos/hardware-configuration.nix \
   "$REPO_DIR/hosts/vm-guest/hardware-configuration.nix"
# The flake only sees files git tracks; stage the generated file.
git -C "$REPO_DIR" add hosts/vm-guest/hardware-configuration.nix 2>/dev/null || true

# --- Swap (prevents the OOM kill on an 8 GB VM) -----------------------------
# Building the full GNOME + herdr/zoom closure exhausts 8 GB RAM and the kernel
# kills `nix build` mid-install. An 8 GB swapfile on the target disk avoids it.
if ! swapon --show | grep -q /mnt/swapfile; then
  echo "==> Creating 8 GB swapfile on target (avoids OOM during build)"
  fallocate -l 8G /mnt/swapfile || dd if=/dev/zero of=/mnt/swapfile bs=1M count=8192
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
fi

# --- Install ----------------------------------------------------------------
INSTALL_OPTS=()
if [ "$SEEDED" = "1" ]; then
  # Packages were copied from the host into /mnt/nix beforehand — install with
  # no substituters so it uses only the local store and never touches the network
  # (this is the fix for the earlier "failed installing packages" download error).
  echo "==> Installing OFFLINE from pre-seeded store (SEEDED=1)"
  INSTALL_OPTS+=(--option substituters "")
else
  echo "==> Installing ONLINE from cache.nixos.org (SEEDED=0)"
fi

nixos-install --flake "$REPO_DIR#vm-guest" "${INSTALL_OPTS[@]}"

# --- Passwords --------------------------------------------------------------
# root password is set interactively by nixos-install above.
echo "==> Set a password for todd (needed for local/GNOME login; SSH uses the key)"
nixos-enter --root /mnt -c 'passwd todd'

echo ""
echo "==> Install complete."
echo "    Remove the ISO from the VM's CDROM (virt-manager), then reboot."
echo "    After boot, from your laptop:  ssh todd@<vm-ip>   (key already authorized)"
read -rp "Reboot now? [y/N] " r
[ "$r" = "y" ] && reboot || echo "Not rebooting. Run 'reboot' when ready."
