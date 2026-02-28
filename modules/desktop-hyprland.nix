# Hyprland Wayland Compositor Configuration
# Minimal Hyprland setup — just enough to boot and use
# Use GDM from main config as the display manager

{ config, pkgs, lib, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.systemPackages = with pkgs; [
    waybar          # Status bar
    wofi            # App launcher
    hyprpaper       # Wallpaper daemon
    hypridle        # Idle management
    hyprlock        # Lock screen
    hyprshot        # Screenshot utility
    wl-clipboard    # Wayland clipboard utilities
    dunst           # Notification daemon
    kitty           # Fallback terminal (WezTerm works too)
  ];

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  environment.variables = {
    NIXOS_OZONE_WL = "1";    # Electron/Chromium Wayland
    MOZ_ENABLE_WAYLAND = "1"; # Firefox Wayland
  };
}
