# KDE Plasma Desktop Environment Configuration
# This module provides KDE Plasma 6 desktop environment
# Can be easily enabled/disabled by commenting out the import in configuration.nix

{ config, pkgs, ... }:

{
  # Enable KDE Plasma 6
  services.desktopManager.plasma6.enable = true;

  # Set wezterm as default terminal for KDE
  environment.variables = {
    TERMINAL = "wezterm";
  };

  # KDE-specific packages
  environment.systemPackages = with pkgs; [
    # KDE Applications
    kdePackages.kate              # Text editor
    kdePackages.konsole           # Terminal (keeping as backup)
    kdePackages.dolphin           # File manager
    kdePackages.ark               # Archive manager
    kdePackages.gwenview          # Image viewer
    kdePackages.okular            # Document viewer
    kdePackages.spectacle         # Screenshot utility
    kdePackages.kalk              # Calculator
    kdePackages.kcalc             # Scientific calculator
    kdePackages.kfind             # File search
    kdePackages.filelight         # Disk usage analyzer

    # Additional utilities
    kdePackages.partitionmanager  # Partition manager
    kdePackages.kcolorchooser     # Color picker

    # KDE configuration file to set wezterm as default terminal
    (pkgs.writeTextFile {
      name = "kde-wezterm-default";
      destination = "/share/applications/wezterm-default.desktop";
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Wezterm
        Exec=wezterm
        Icon=wezterm
        Terminal=false
        Categories=System;TerminalEmulator;
        X-KDE-TerminalApplication=true
      '';
    })
  ];

  # XDG portal for KDE
  xdg.portal.extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
}
