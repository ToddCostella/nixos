# Home Manager desktop packages for todd — GUI apps only.
# Imported only for hosts with a desktop environment (e.g. nixos-dev).
# Headless-safe packages are in todd-base.nix.

{ pkgs, ... }:
{
  imports = [ ./mail.nix ];

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    claude-desktop-fhs
    slack
    obsidian
    signal-desktop
    zoom-us
    figma-linux
    dbeaver-bin
    bcompare
    wezterm
    aerc
    hugo
    pinta
    apostrophe
    rainfrog
    maestral
  ];

  # --- Dropbox (via Maestral) ---
  # Maestral is an open-source Dropbox client. We switched away from the official
  # nixpkgs `dropbox` package: its bwrap FHS sandbox never completed the link
  # handshake on this GNOME/Wayland setup (kept rewriting unlink.db, never armed
  # inotify watches), and it can't surface the browser link flow from the sandbox.
  # Maestral runs unsandboxed, links via a URL it prints to the terminal, and is
  # designed for headless/systemd use.
  #
  # First-time setup is interactive (run once in a terminal):
  #   maestral auth link          # prints an auth URL; paste the token back
  #   maestral start              # or let the service below run it
  # Point it at the existing ~/Dropbox when prompted so it matches local files
  # instead of re-downloading. See the systemd service below for supervision.
  # (maestral is in home.packages above.)

  systemd.user.services.maestral = {
    Unit = {
      Description = "Maestral Dropbox sync daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "exec";
      ExecStart = "${pkgs.maestral}/bin/maestral start -f";
      ExecStop = "${pkgs.maestral}/bin/maestral stop";
      Restart = "on-failure";
      RestartSec = 10;
      Nice = 10;
    };
  };

  # --- Proton Mail Bridge ---
  # Runs headless as a systemd user service (protonmail-bridge --noninteractive),
  # exposing standard IMAP/SMTP on localhost for any mail client (e.g. aerc):
  #   IMAP: 127.0.0.1:1143   SMTP: 127.0.0.1:1025
  #
  # Proton's E2E encryption means there is no direct IMAP — everything goes
  # through this local Bridge. Credentials are stored in the GNOME keyring after
  # a one-time interactive login (this cannot be done declaratively):
  #   1. Rebuild, then temporarily stop the service:
  #        systemctl --user stop protonmail-bridge
  #   2. Log in via the CLI:
  #        protonmail-bridge --cli
  #        >>> login          (enter Proton email, password, 2FA)
  #        >>> info           (shows the Bridge-generated IMAP/SMTP password)
  #        >>> exit
  #   3. Restart the service:
  #        systemctl --user start protonmail-bridge
  # Point your mail client at 127.0.0.1 with the credentials from `info`
  # (NOT your real Proton password — the Bridge mints its own).
  services.protonmail-bridge = {
    enable = true;
    logLevel = "info";
  };
}
