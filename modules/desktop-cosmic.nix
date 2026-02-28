# COSMIC Desktop Environment Configuration
# This module provides System76's COSMIC desktop environment
# Can be easily enabled/disabled by commenting out the import in configuration.nix
#
# Note: COSMIC is still in alpha. To use it:
# 1. Add this import to configuration.nix
# 2. Comment out desktop-gnome.nix import (or keep both for session selection at login)
# 3. Run: sudo nixos-rebuild switch

{ config, pkgs, lib, ... }:

{
  # Enable COSMIC desktop environment
  services.desktopManager.cosmic.enable = true;

  # Note: Using GDM from main config as the display manager
  # GDM can show both GNOME and COSMIC sessions at login
  # Uncomment below (and disable GDM) if you want COSMIC's native greeter:
  # services.displayManager.cosmic-greeter.enable = true;

  # COSMIC-specific packages
  environment.systemPackages = with pkgs; [
    # COSMIC applications (many are included by default with the desktop)
    cosmic-files        # File manager
    cosmic-edit         # Text editor
    cosmic-term         # Terminal emulator
    cosmic-store        # App store
    cosmic-screenshot   # Screenshot utility

    # Additional utilities that work well with COSMIC
    wl-clipboard        # Wayland clipboard utilities (may already be installed)
  ];

  # XDG portal for COSMIC (uses wlr portal for Wayland compatibility)
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-cosmic ];
}
