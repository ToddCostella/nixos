# NordVPN via wgnord — a POSIX-shell client for NordVPN's WireGuard (NordLynx) servers.
#
# This uses the `wgnord` package from nixpkgs (no proprietary client, no third-party
# flake). It connects to NordVPN's WireGuard servers using a NordVPN access token.
#
# One-time setup after `nixos-rebuild switch`:
#   1. Generate a NordVPN access token: https://my.nordaccount.com/  (Services →
#      NordVPN → Manual setup → "Generate new token", choose "Doesn't expire").
#   2. Log in (writes auth token + WireGuard credentials to /var/lib/wgnord):
#        sudo wgnord login <YOUR_TOKEN>
#
# Usage:
#   sudo wgnord c United_States   # connect to a country (see `wgnord` for the list)
#   sudo wgnord c                 # connect to the recommended server
#   sudo wgnord d                 # disconnect
#
# Notes:
#   - WireGuard/NordLynx only — no OpenVPN, meshnet, or built-in kill switch.
#   - The access token is a runtime secret stored under /var/lib/wgnord; it is never
#     committed to this repo.

{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    wgnord          # the client
    wireguard-tools # `wg` / `wg-quick`, required to bring the tunnel up
    openresolv      # `resolvconf`, used by wg-quick to set the NordVPN DNS
  ];

  # wgnord reads its WireGuard template from /var/lib/wgnord/template.conf. The nixpkgs
  # package does not install one, so provision it declaratively. wgnord fills in the
  # PRIVKEY / SERVER_PUBKEY / SERVER_IP placeholders at connect time.
  environment.etc."wgnord/template.conf".text = ''
    [Interface]
    PrivateKey = PRIVKEY
    Address = 10.5.0.2/32
    MTU = 1350
    DNS = 103.86.96.100 103.86.99.100

    [Peer]
    PublicKey = SERVER_PUBKEY
    AllowedIPs = 0.0.0.0/0, ::/0
    Endpoint = SERVER_IP:51820
    PersistentKeepalive = 25
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/wgnord 0700 root root -"
    "L+ /var/lib/wgnord/template.conf - - - - /etc/wgnord/template.conf"
  ];
}
