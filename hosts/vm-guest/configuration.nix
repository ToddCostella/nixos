# NixOS Configuration for vm-guest — a persistent libvirt/QEMU VM.
#
# A daily-driver-equivalent VM: same desktop + tools as nixos-dev (via the shared
# ../nixos-dev/desktop-tools.nix), but with VM-appropriate hardware/boot settings
# instead of the Dell laptop's physical tuning. modules/common.nix (base) and
# home-manager come from the flake, matching nixos-dev.
#
# Install: see docs/vm-guest-install.md.
{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix          # generated inside the VM at install
    ../nixos-dev/desktop-tools.nix        # shared desktop + full tool set
  ];

  # Boot loader — UEFI + systemd-boot (matches nixos-dev; VM is created with
  # OVMF/UEFI firmware, see install doc).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking — libvirt NAT via NetworkManager + DHCP. Public DNS (the VM can't
  # reach nixos-dev's home AdGuard box at 10.0.0.8).
  networking.hostName = "vm-guest";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.enable = true;

  # Same user groups as nixos-dev minus libvirtd (no nested virt in the guest).
  users.users.todd.extraGroups = [ "networkmanager" "wheel" "docker" "dialout" ];

  # Guest integration for virt-manager/virt-viewer: SPICE clipboard sharing +
  # display auto-resize, and the QEMU guest agent for graceful shutdown/info.
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  system.stateVersion = "24.05";
}
