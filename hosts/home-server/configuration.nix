# NixOS Configuration for home-server (headless mini PC)
# DNS, home-lab services. Shared config is in modules/common.nix.

{ config, pkgs, lib, inputs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS support for media pool (sdb+sdd mirror, sdc cache)
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  services.zfs.autoScrub.enable = true;   # Weekly integrity check
  services.zfs.autoSnapshot.enable = true; # Automatic snapshots


  networking.hostName = "home-server";
  networking.hostId = "a1b2c3d4";  # Required for ZFS — must be unique per host
  networking.networkmanager.enable = true;

  # Static IP — update interface name after first boot if different (check with `ip addr`)
  networking.interfaces.eno1.ipv4.addresses = [{
    address = "10.0.0.8";
    prefixLength = 24;
  }];
  networking.defaultGateway = "10.0.0.1";
  networking.nameservers = [ "127.0.0.1" "1.1.1.1" ];  # AdGuard on localhost, Cloudflare fallback

  # Full user group list for server
  users.users.todd.extraGroups = [ "networkmanager" "wheel" ];

  # Authorize Todd's 1Password SSH key for remote access and nixos-rebuild --target-host
  users.users.todd.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR93ztnY9HKCSLlFtwsdrEcwx8ovgpGhJTBB7XS2l5o"
  ];

  # 1Password (needed for git signing in todd-base.nix)
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "todd" ];
  };

  # AdGuard Home — local DNS server with ad blocking
  services.adguardhome = {
    enable = true;
    mutableSettings = true;  # Allow changes via web UI to persist
    settings = {
      http.address = "0.0.0.0:3000";  # Web UI on port 3000
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"  # Cloudflare DoH
          "https://dns.google/dns-query"           # Google DoH fallback
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
  };

  # Allow passwordless sudo so nixos-rebuild --target-host works without a local password set
  security.sudo.wheelNeedsPassword = false;

  # Jellyfin — media server, serves from ZFS media pool
  services.jellyfin = {
    enable = true;
    dataDir = "/var/lib/jellyfin";
    openFirewall = true;
  };

  # Give jellyfin user access to media pool
  users.users.jellyfin.extraGroups = [ "render" "video" ];

  networking.firewall.allowedTCPPorts = [ 53 80 3000 8096 ];  # DNS, HTTP, AdGuard web UI, Jellyfin
  networking.firewall.allowedUDPPorts = [ 53 ];                # DNS over UDP

  environment.systemPackages = with pkgs; [ tmux ];

  system.stateVersion = "25.11";
}
