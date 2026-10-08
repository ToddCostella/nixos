# Hyprland Wayland compositor — system side of the Omarchy-flavoured session.
#
# Installed ALONGSIDE GNOME (not as a specialisation): GDM lists both "GNOME"
# and "Hyprland" in its session picker, so switching is a log out / log in, no
# reboot. Pick plain "Hyprland", not "Hyprland (uwsm-managed)" (shipped by the
# package): Home Manager already manages the session's systemd target.
#
# gnome-keyring stays on (GDM's PAM unlocks it for either session), so
# 1Password, git signing and the SSH agent behave the same under Hyprland.
#
# All look-and-feel (keybindings, Waybar, Walker, Mako, Hyprlock, theme) is user
# config in home/hyprland/.
{ config, pkgs, lib, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # PAM service so hyprlock can verify the password.
  programs.hyprlock.enable = true;

  # Omarchy's UI font (Waybar, Mako, Walker, Hyprlock).
  fonts.packages = [ pkgs.nerd-fonts.caskaydia-mono ];

  environment.systemPackages = with pkgs; [
    wl-clipboard
    networkmanagerapplet  # nm-connection-editor, opened from the Waybar network icon
  ];

  # Electron/Chromium apps run natively on Wayland (both sessions are Wayland).
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
