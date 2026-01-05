# Playwright Development Environment
# Provides all system dependencies required for running Playwright E2E tests
# with Chromium browser in the Buoyancy Platform project
#
# Usage: Import this file in configuration.nix:
#   imports = [
#     ./playwright-dev.nix
#   ];

{ config, pkgs, ... }:

{
  # Add Playwright system dependencies to nix-ld for dynamically linked executables
  programs.nix-ld.libraries = with pkgs; [
    # Core browser dependencies
    glib
    gobject-introspection
    nss
    nspr

    # Accessibility
    atk
    at-spi2-atk
    at-spi2-core

    # Display and rendering
    cups
    dbus
    libdrm
    expat
    libxcb
    libxkbcommon

    # X11 libraries
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr

    # Graphics
    mesa
    libgbm
    libGL

    # Font rendering
    pango
    cairo

    # Audio
    alsa-lib

    # System libraries
    systemd  # Provides libudev

    # GTK and theming
    gtk3
    gdk-pixbuf

    # Additional utilities for browser automation
    curl
    wget
  ];

  # Optionally add Playwright CLI to system packages
  # Uncomment if you want 'playwright' command available system-wide
  # environment.systemPackages = with pkgs; [
  #   playwright-driver
  # ];
}
