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

  # Hide the broken "Hyprland (uwsm-managed)" entry from GDM.
  #
  # The hyprland package ships BOTH hyprland.desktop and hyprland-uwsm.desktop
  # in share/wayland-sessions/, so GDM lists two Hyprland sessions even though
  # programs.hyprland.withUWSM is false. Picking the uwsm one fails outright —
  # GDM logs "Cannot find a command for specified session: hyprland-uwsm" and
  # drops straight back to the login screen (seen 2026-10-08). Home Manager
  # already manages hyprland-session.target, so uwsm is not wanted here.
  #
  # There is no services.displayManager.hiddenSessions in this nixpkgs, so shadow
  # the entry instead: /etc wins over the package's own wayland-sessions dir, and
  # Hidden=true tells the greeter not to list it.
  environment.etc."wayland-sessions/hyprland-uwsm.desktop".text = ''
    [Desktop Entry]
    Name=Hyprland (uwsm-managed)
    Comment=Disabled in modules/desktop-hyprland.nix — uwsm is not configured here
    Exec=false
    Type=Application
    Hidden=true
    NoDisplay=true
  '';

  # hypridle: keep it OUT of GNOME sessions.
  #
  # programs.hyprlock/hyprland pull in a SYSTEM-level hypridle user unit whose
  # [Install] is WantedBy=graphical-session.target — which GNOME also reaches.
  # Under GNOME there is no Hyprland socket, so hypridle throws std::runtime_error,
  # dumps core, and systemd restarts it until it gives up ("Failed to start
  # Hyprland's idle daemon", 2026-10-08). The Home Manager unit in home/hyprland/
  # is already correctly bound to hyprland-session.target; this stops the
  # system-level copy from competing with it.
  systemd.user.services.hypridle.wantedBy = lib.mkForce [ ];

  # Omarchy's UI font (Waybar, Mako, Walker, Hyprlock).
  fonts.packages = [ pkgs.nerd-fonts.caskaydia-mono ];

  environment.systemPackages = with pkgs; [
    wl-clipboard
    networkmanagerapplet  # nm-connection-editor, opened from the Waybar network icon
  ];

  # Electron/Chromium apps run natively on Wayland (both sessions are Wayland).
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
