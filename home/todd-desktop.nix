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
    ghostty
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

  # --- Ghostty terminal ---
  # Added alongside WezTerm, not replacing it: WezTerm stays the daily driver and
  # herdr host. Ghostty exists for terminal-browser, which needs the *full* kitty
  # graphics protocol — WezTerm implements iTerm2 inline images plus only partial
  # kitty graphics, which is why terminal-browser's supported list names ghostty,
  # kitty, cmux and vscode but not WezTerm.
  #
  # NOTE: run terminal-browser in ghostty *directly*, not inside herdr. Multiplexers
  # rewrite program output and break terminal graphics commands (the same reason
  # yazi's image previews are disabled — see todd-base.nix).
  #
  # Settings mirror ~/.config/wezterm/wezterm.lua as closely as ghostty allows.
  # home-manager (pinned rev) has no programs.ghostty module, so this is home.file.
  home.file.".config/ghostty/config".text = ''
    # Managed by home-manager (home/todd-desktop.nix). Edit there, not here.
    # Ported from ~/.config/wezterm/wezterm.lua — keep the two in sync.

    font-size = 11
    theme = Dracula

    # wezterm line_height = 1.1. Ghostty has no line-height multiplier; it takes a
    # percentage adjustment to the computed cell height, so +10% is the equivalent.
    adjust-cell-height = 10%

    # wezterm window_padding: left/right 8, top 8, bottom 25. Ghostty's padding is
    # symmetric per axis (x = both sides, y = top AND bottom), so the asymmetric
    # bottom=25 cannot be reproduced exactly. That padding was a workaround for a
    # WezTerm/GNOME line-cutoff bug that ghostty does not have, so x=8/y=8 matches
    # the intent rather than the number.
    window-padding-x = 8
    window-padding-y = 8

    # wezterm window_close_confirmation = 'NeverPrompt'
    confirm-close-surface = false

    # wezterm scrollback_lines = 3500
    scrollback-limit = 3500

    # Not set, because ghostty's defaults already match the wezterm config:
    #   window-decoration = auto  (≈ wezterm "TITLE | RESIZE")
    #   background-opacity = 1    (wezterm window_background_opacity = 1.0)
    # Several other wezterm settings have no ghostty analogue and need none —
    # they were workarounds for WezTerm-specific GNOME/Wayland rendering bugs
    # (front_end = "OpenGL", freetype_*_target, allow_square_glyphs_to_overflow_width,
    # custom_block_glyphs, adjust_window_size_when_changing_font_size).

    # Always open a new window rather than reusing an existing instance
    # (wezterm prefer_to_spawn_tabs = false).
    gtk-single-instance = false

    # Ctrl+Shift+C / Ctrl+Shift+V are already ghostty defaults, so they need no
    # entry here. Ctrl+V is deliberately left unbound so Claude Code receives it
    # directly for image pasting — same rationale as the wezterm config.
    #
    # NOT PORTED: wezterm's Ctrl+Alt+V clipboard-image-to-path binding. It calls
    # `wezterm-clip2path <pane_id>`, which needs a WezTerm pane id and the wezterm
    # CLI, so it has no ghostty equivalent.
    #
    # NOT PORTED: the Alt+1..9 SendKey passthroughs. Those exist because WezTerm
    # would otherwise swallow the chords before herdr's switch_tab saw them;
    # ghostty does not bind Alt+number, so the keys already reach the shell.
  '';

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
