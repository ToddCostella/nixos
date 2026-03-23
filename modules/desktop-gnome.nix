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

  # Set wezterm as default terminal for GNOME
  # This sets the default x-terminal-emulator alternative
  environment.variables = {
    TERMINAL = "wezterm";
  };

  # Declaratively enable GNOME extensions
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/shell" = {
        enabled-extensions = [
          "forge@jmmaranan.com"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
          "just-perfection-desktop@just-perfection"
          "tactile@lundal.io"
          "switcher@landau.fi"
          "sound-output-device-chooser@kgshank.net"
        ];
      };
    };
  }];

  # GNOME-specific packages
  environment.systemPackages = with pkgs; [
    # GNOME Extensions
    gnomeExtensions.forge
    gnomeExtensions.workspace-indicator
    gnomeExtensions.just-perfection
    gnomeExtensions.sound-output-device-chooser

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
