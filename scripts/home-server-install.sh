#!/usr/bin/env bash
# NixOS installation script for home-server (desktop PC)
# Run as root from the NixOS minimal ISO live environment.
#
# Drive layout:
#   sda (465.8G Samsung 860 EVO)  — NixOS system drive
#   sdb (447.1G SanDisk)          \
#   sdd (465.8G Samsung 860 EVO)  / ZFS mirror pool (media/data)
#   sdc (238.5G M4-CT256M4SSD2)   — ZFS L2ARC cache
#   sde (114.6G SanDisk USB)      — installer (do not touch)

set -euo pipefail

SYSTEM_DRIVE="/dev/sda"
ZFS_MIRROR_1="/dev/sdb"
ZFS_MIRROR_2="/dev/sdd"
ZFS_CACHE="/dev/sdc"
REPO="https://github.com/ToddCostella/nixos.git"

echo "==> Drive layout:"
lsblk -d -o NAME,SIZE,MODEL /dev/sda /dev/sdb /dev/sdc /dev/sdd
echo ""
echo "  System drive : $SYSTEM_DRIVE"
echo "  ZFS mirror   : $ZFS_MIRROR_1 + $ZFS_MIRROR_2"
echo "  ZFS cache    : $ZFS_CACHE"
echo ""
read -rp "This will WIPE sda, sdb, sdc, sdd. Type 'yes' to continue: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

echo "==> Cleaning up any previous install state"
umount /mnt/boot 2>/dev/null || true
umount /mnt 2>/dev/null || true
zpool destroy media 2>/dev/null || true
wipefs -a "$SYSTEM_DRIVE" || true
wipefs -a "$ZFS_MIRROR_1" || true
wipefs -a "$ZFS_MIRROR_2" || true
wipefs -a "$ZFS_CACHE" || true
sgdisk --zap-all "$SYSTEM_DRIVE" || true
sgdisk --zap-all "$ZFS_MIRROR_1" || true
sgdisk --zap-all "$ZFS_MIRROR_2" || true
sgdisk --zap-all "$ZFS_CACHE" || true
partprobe 2>/dev/null || true
sleep 2

echo "==> Partitioning system drive $SYSTEM_DRIVE"
parted "$SYSTEM_DRIVE" -- mklabel gpt
parted "$SYSTEM_DRIVE" -- mkpart ESP fat32 1MiB 512MiB
parted "$SYSTEM_DRIVE" -- set 1 esp on
parted "$SYSTEM_DRIVE" -- mkpart primary ext4 512MiB 100%

echo "==> Formatting system partitions"
mkfs.fat -F 32 -n boot "${SYSTEM_DRIVE}1"
mkfs.ext4 -L nixos -F "${SYSTEM_DRIVE}2"

echo "==> Mounting system drive"
mount "${SYSTEM_DRIVE}2" /mnt
mkdir -p /mnt/boot
mount "${SYSTEM_DRIVE}1" /mnt/boot

echo "==> Creating ZFS mirror pool (media)"
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O mountpoint=/media \
  media mirror "$ZFS_MIRROR_1" "$ZFS_MIRROR_2"

echo "==> Adding L2ARC cache to ZFS pool"
zpool add -f media cache "$ZFS_CACHE"

echo "==> Creating ZFS datasets"
zfs create media/jellyfin
zfs create media/immich
zfs create media/syncthing

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
