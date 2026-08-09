# Remote Terminal Access - mosh + SSH hardening
# Enables persistent terminal sessions accessible from iOS devices
# via Mosh, and from the desktop via WezTerm + herdr.

{ config, pkgs, ... }:
{
  # The terminal multiplexer (herdr) is configured via Home Manager (home/todd-base.nix)

  # Mosh - resilient remote connections (auto-opens UDP 60000-61000)
  programs.mosh.enable = true;

  # SSH hardening - key-only auth, no root login
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "todd" ];
    };
  };
}
