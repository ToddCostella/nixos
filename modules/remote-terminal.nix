# Remote Terminal Access - tmux + mosh + SSH hardening
# Enables persistent terminal sessions accessible from iOS devices
# via Mosh, and from the desktop via WezTerm + tmux.

{ config, pkgs, ... }:
{
  # tmux is configured in home.nix via Home Manager

  # Mosh - resilient remote connections (auto-opens UDP 60000-61000)
  programs.mosh.enable = true;

  # SSH hardening - key-only auth, no root login
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "todd" ];
    };
  };
}
