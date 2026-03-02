#!/usr/bin/env bash
# NixOS installation script for home-server (eMMC mini PC)
# Run as root from the NixOS minimal ISO live environment.
# Assumes the internal eMMC drive is /dev/mmcblk1 — verify with lsblk first.

set -euo pipefail

DRIVE="/dev/mmcblk1"
REPO="https://github.com/ToddCostella/nixos.git"

echo "==> Verifying drive: $DRIVE"
lsblk "$DRIVE"
echo ""
read -rp "Is this correct? This will WIPE $DRIVE. Type 'yes' to continue: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

echo "==> Wiping and partitioning $DRIVE"
parted "$DRIVE" -- mklabel gpt
parted "$DRIVE" -- mkpart ESP fat32 1MiB 512MiB
parted "$DRIVE" -- set 1 esp on
parted "$DRIVE" -- mkpart primary ext4 512MiB 100%

echo "==> Formatting partitions"
mkfs.fat -F 32 -n boot "${DRIVE}p1"
mkfs.ext4 -L nixos -F "${DRIVE}p2"

echo "==> Mounting"
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

echo "==> Generating hardware configuration"
nixos-generate-config --root /mnt

echo "==> Cloning nixos-config repo"
mkdir -p /mnt/home/todd
nix-shell -p git --run "git clone $REPO /mnt/home/todd/nixos-config"

echo "==> Copying generated hardware config into repo"
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/todd/nixos-config/hosts/home-server/hardware-configuration.nix

echo "==> Installing NixOS"
nixos-install --flake /mnt/home/todd/nixos-config#home-server --no-root-passwd

echo ""
echo "==> Installation complete. Rebooting in 5 seconds..."
sleep 5
reboot
