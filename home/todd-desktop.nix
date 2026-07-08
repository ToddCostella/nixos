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
    dropbox
    pinta
    apostrophe
    rainfrog
  ];

  # --- Dropbox ---
  # Custom systemd user service (NOT the upstream services.dropbox module — that
  # module remaps HOME to ~/.dropbox-hm and scrambled the existing linked-account
  # config). This runs the self-updating daemon with the normal HOME, keeping
  # state at the canonical ~/.dropbox and files at ~/Dropbox. Starts on login,
  # restarts on crash. Re-establishes inotify watches that the unsupervised
  # daemon had lost.
  systemd.user.services.dropbox = {
    Unit.Description = "Dropbox daemon";
    Install.WantedBy = [ "default.target" ];
    Service = {
      # The nixpkgs `dropbox` binary is a launcher that forks the real daemon
      # (in ~/.dropbox-dist) and exits — so Type=simple loses track of it.
      # Type=forking + PIDFile lets systemd supervise the actual daemon.
      Type = "forking";
      PIDFile = "%h/.dropbox/dropbox.pid";
      ExecStart = "${pkgs.dropbox}/bin/dropbox start";
      ExecStop = "${pkgs.dropbox}/bin/dropbox stop";
      Restart = "on-failure";
      RestartSec = 5;
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
