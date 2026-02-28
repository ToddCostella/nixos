# NixOS Configuration for home-server (headless mini PC)
# DNS, home-lab services. Shared config is in modules/common.nix.

{ config, pkgs, lib, inputs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "home-server";
  networking.networkmanager.enable = true;

  # Full user group list for server
  users.users.todd.extraGroups = [ "networkmanager" "wheel" ];

  # 1Password (needed for git signing in todd-base.nix)
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "todd" ];
  };

  # DNS server (configure once hardware is known)
  # services.adguardhome = { enable = true; ... };

  networking.firewall.allowedTCPPorts = [ 53 80 ];

  environment.systemPackages = with pkgs; [ tmux ];

  system.stateVersion = "25.05";  # Update to match installer ISO version
}
