# Cinnamon Desktop Environment Configuration
# This module provides the Cinnamon desktop environment
# Can be easily enabled/disabled by commenting out the import in configuration.nix

{ config, pkgs, lib, ... }:

{
  # Enable Cinnamon
  services.xserver.desktopManager.cinnamon.enable = true;

  # Set wezterm as default terminal for Cinnamon
  environment.variables = {
    TERMINAL = "wezterm";
  };

  # Cinnamon-specific packages
  environment.systemPackages = with pkgs; [
    # Cinnamon applications
    gnome-terminal           # Terminal (keeping as backup)
    nemo                     # File manager (Cinnamon's fork of Nautilus)
    nemo-fileroller          # Archive manager integration
    xed-editor               # Text editor
    xviewer                  # Image viewer
    xreader                  # Document viewer
    pix                      # Photo organizer
    gnome-calculator         # Calculator

    # Additional utilities
    cinnamon-screensaver
  ];

  # XDG portal for Cinnamon (uses GTK portal)
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Cinnamon reads the x-terminal-emulator alternative
  # Create a desktop file for wezterm with proper terminal category
  environment.etc."xdg/cinnamon-wezterm.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Wezterm
      Exec=wezterm
      Icon=wezterm
      Terminal=false
      Categories=System;TerminalEmulator;
      X-GNOME-UsesNotifications=true
    '';
  };
}
