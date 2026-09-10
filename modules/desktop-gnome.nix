# GNOME Desktop Environment Configuration
# This module provides the GNOME desktop environment
# Can be easily enabled/disabled by commenting out the import in configuration.nix

{ config, pkgs, lib, ... }:

{
  # Enable GNOME
  services.desktopManager.gnome.enable = true;

  # GNOME-specific services
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gnome-online-accounts.enable = true;

  # GPaste clipboard-history daemon (pairs with the GPaste GNOME Shell extension
  # and the org/gnome/GPaste dconf settings below). Bound to Super+V.
  programs.gpaste.enable = true;

  # Set wezterm as default terminal for GNOME
  # This sets the default x-terminal-emulator alternative
  environment.variables = {
    TERMINAL = "wezterm";
  };

  # Declaratively enable GNOME extensions + keybindings.
  # Keybindings below were captured from a live setup (previously only in dconf,
  # not version-controlled) and made declarative here. `gvariant` helpers give
  # the correct dconf types.
  programs.dconf.profiles.user.databases = [{
    settings = with lib.gvariant; {
      "org/gnome/shell" = {
        enabled-extensions = [
          "forge@jmmaranan.com"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
          "just-perfection-desktop@just-perfection"
          "tactile@lundal.io"
          "switcher@landau.fi"
          "GPaste@gnome-shell-extensions.gnome.org"
        ];
      };

      # Fixed 10 workspaces (not dynamic) — required for Super+1..0 switching.
      "org/gnome/mutter".dynamic-workspaces = false;
      "org/gnome/desktop/wm/preferences".num-workspaces = mkInt32 10;

      # Window-manager keybindings: workspace switch/move, close, fullscreen.
      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Super><Shift>q" "<Alt>F4" ];
        toggle-fullscreen = [ "<Super>f" ];
        switch-windows = [ "<Alt>Tab" ];
        switch-windows-backward = [ "<Shift><Alt>Tab" ];
        switch-to-workspace-1 = [ "<Super>1" ];
        switch-to-workspace-2 = [ "<Super>2" ];
        switch-to-workspace-3 = [ "<Super>3" ];
        switch-to-workspace-4 = [ "<Super>4" ];
        switch-to-workspace-5 = [ "<Super>5" ];
        switch-to-workspace-6 = [ "<Super>6" ];
        switch-to-workspace-7 = [ "<Super>7" ];
        switch-to-workspace-8 = [ "<Super>8" ];
        switch-to-workspace-9 = [ "<Super>9" ];
        switch-to-workspace-10 = [ "<Super>0" ];
        move-to-workspace-1 = [ "<Super><Shift>1" ];
        move-to-workspace-2 = [ "<Super><Shift>2" ];
        move-to-workspace-3 = [ "<Super><Shift>3" ];
        move-to-workspace-4 = [ "<Super><Shift>4" ];
        move-to-workspace-5 = [ "<Super><Shift>5" ];
        move-to-workspace-6 = [ "<Super><Shift>6" ];
        move-to-workspace-7 = [ "<Super><Shift>7" ];
        move-to-workspace-8 = [ "<Super><Shift>8" ];
        move-to-workspace-9 = [ "<Super><Shift>9" ];
        move-to-workspace-10 = [ "<Super><Shift>0" ];
      };

      # Super+d opens the app grid.
      "org/gnome/shell/keybindings".toggle-application-view = [ "<Super>d" ];

      # Bind GNOME's built-in screenshot UI to Print. It was unset (@as []), so
      # Print did nothing / the old broken custom script ran instead. The
      # built-in UI (Screen/Window/Selection overlay) captures via Mutter and
      # copies to the clipboard — the only working screenshot path on GNOME
      # Wayland (see desktop-tools.nix for why gnome-screenshot/grim don't work).
      "org/gnome/shell/keybindings".show-screenshot-ui = [ "Print" ];

      # Custom launcher keybindings.
      # NOTE: the old Print / <Shift>Print screenshot bindings (custom4/custom5 →
      # screenshot-area / screenshot-quick) were REMOVED. Those scripts wrap
      # `gnome-screenshot`, which is broken on GNOME Wayland (it can't use the
      # Shell screenshot interface and falls back to an empty X11 capture — exit
      # 0 but no image, so the clipboard never updates). Leaving Print/<Shift>Print
      # unbound here restores GNOME's built-in screenshot UI on those keys, which
      # captures via Mutter and copies to the clipboard correctly.
      "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Terminal"; command = "wezterm"; binding = "<Super>Return";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        name = "Web Browser"; command = "firefox"; binding = "<Super><Shift>w";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
        name = "File Manager"; command = "nautilus"; binding = "<Super>e";
      };

      # Forge tiling extension: focus/move/resize (Super+hjkl), splits, floating,
      # gap size, and snap-to-thirds.
      "org/gnome/shell/extensions/forge" = {
        focus-border-toggle = false;
        show-tab-decorations = false;
        split-direction = "horizontal";
        stacked-tiling-mode-enabled = true;
        tiling-mode-enabled = true;
        window-gap-size = mkUint32 4;
        focus-left = [ "<Super>h" ];
        focus-down = [ "<Super>j" ];
        focus-up = [ "<Super>k" ];
        focus-right = [ "<Super>l" ];
        move-left = [ "<Super><Shift>h" ];
        move-down = [ "<Super><Shift>j" ];
        move-up = [ "<Super><Shift>k" ];
        move-right = [ "<Super><Shift>l" ];
        resize-left = [ "<Super><Control>h" ];
        resize-down = [ "<Super><Control>j" ];
        resize-up = [ "<Super><Control>k" ];
        resize-right = [ "<Super><Control>l" ];
        split-layout-horizontal = [ "<Super>b" ];
        # Moved off Super+V (now GPaste clipboard history) — see org/gnome/GPaste.
        split-layout-toggle = [ "<Super><Shift>v" ];
        stacking-toggle = [ "<Super>w" ];
        window-layout-toggle = [ "<Super>s" ];
        window-toggle-float = [ "<Super><Shift>space" ];
      };
      "org/gnome/shell/extensions/forge/keybindings" = {
        con-split-horizontal = [ "<Super>z" ];
        con-split-layout-toggle = [ "<Super>g" ];
        # Moved off Super+V (now GPaste clipboard history) — see org/gnome/GPaste.
        con-split-vertical = [ "<Super><Shift>v" ];
        con-stacked-layout-toggle = [ "<Shift><Super>s" ];
        con-tabbed-layout-toggle = [ "<Shift><Super>t" ];
        con-tabbed-showtab-decoration-toggle = [ "<Control><Alt>y" ];
        focus-border-toggle = [ "<Super>x" ];
        prefs-tiling-toggle = [ "<Super>w" ];
        window-focus-left = [ "<Super>h" ];
        window-focus-down = [ "<Super>j" ];
        window-focus-up = [ "<Super>k" ];
        window-focus-right = [ "<Super>l" ];
        window-move-left = [ "<Shift><Super>h" ];
        window-move-down = [ "<Shift><Super>j" ];
        window-move-up = [ "<Shift><Super>k" ];
        window-move-right = [ "<Shift><Super>l" ];
        window-swap-left = [ "<Control><Super>h" ];
        window-swap-down = [ "<Control><Super>j" ];
        window-swap-up = [ "<Control><Super>k" ];
        window-swap-right = [ "<Control><Super>l" ];
        window-swap-last-active = [ "<Super>Return" ];
        window-gap-size-increase = [ "<Control><Super>plus" ];
        window-gap-size-decrease = [ "<Control><Super>minus" ];
        window-toggle-float = [ "<Super>c" ];
        window-toggle-always-float = [ "<Shift><Super>c" ];
        workspace-active-tile-toggle = [ "<Shift><Super>w" ];
        window-snap-center = [ "<Control><Alt>c" ];
        window-snap-one-third-left = [ "<Control><Alt>d" ];
        window-snap-one-third-right = [ "<Control><Alt>g" ];
        window-snap-two-third-left = [ "<Control><Alt>e" ];
        window-snap-two-third-right = [ "<Control><Alt>t" ];
      };

      # GPaste clipboard-history manager. Super+V opens the history UI (took over
      # from Forge's split toggle, now on Super+Shift+V). Tracks the system
      # clipboard, including Neovim yanks via the wl-copy provider.
      "org/gnome/GPaste" = {
        history-name = "history";
        max-history-size = mkUint32 100;
        max-displayed-history-size = mkUint32 40;
        images-support = true;
        track-changes = true;
        # Show the history menu at the pointer.
        show-history = "<Super>v";
      };
    };
  }];

  # GNOME-specific packages
  environment.systemPackages = with pkgs; [
    # GNOME Extensions (must match the enabled-extensions dconf list above)
    gnomeExtensions.forge
    gnomeExtensions.workspace-indicator
    gnomeExtensions.just-perfection
    gnomeExtensions.tactile
    gnomeExtensions.switcher
    # NB: no gnomeExtensions.gpaste — the GPaste shell extension ships inside the
    # `gpaste` package, pulled in by programs.gpaste.enable above.

    # GNOME Utilities
    gnome-tweaks

    # Screenshot utilities (GNOME-specific)
    gnome-screenshot

    # Office suite
    libreoffice

    # Backup software
    pika-backup

    # Desktop entry for wezterm to ensure it appears in GNOME's terminal launcher
    (pkgs.writeTextFile {
      name = "gnome-wezterm-default";
      destination = "/share/glib-2.0/schemas/99_gnome-wezterm.gschema.override";
      text = ''
        [org.gnome.desktop.default-applications.terminal]
        exec='wezterm'
        exec-arg=' '
      '';
    })
  ];

  # XDG portal for GNOME
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
}
