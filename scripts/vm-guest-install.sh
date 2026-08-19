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
# If the closure was pre-seeded from the host (nix copy --to ...root=/mnt),
# install offline. Set SEEDED=0 to allow downloads from cache.nixos.org instead.
SEEDED="${SEEDED:-1}"

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
cp /mnt/etc/nixos/hardware-configuration.nix \
   "$REPO_DIR/hosts/vm-guest/hardware-configuration.nix"
# The flake only sees files git tracks; stage the generated file.
git -C "$REPO_DIR" add hosts/vm-guest/hardware-configuration.nix 2>/dev/null || true

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
