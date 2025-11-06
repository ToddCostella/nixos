# Multi-Desktop Environment Compatibility Configuration
# This module resolves conflicts when multiple desktop environments are enabled
# Import this AFTER all desktop environment modules in configuration.nix

{ config, pkgs, lib, ... }:

let
  gnomeEnabled = config.services.desktopManager.gnome.enable;
  kdeEnabled = config.services.desktopManager.plasma6.enable;
  cinnamonEnabled = config.services.xserver.desktopManager.cinnamon.enable;
in
{
  # Resolve gsettings conflicts between GNOME and Cinnamon
  # Use a merged gsettings override directory
  environment.sessionVariables = lib.mkForce (
    if gnomeEnabled && cinnamonEnabled then {
      # When both are enabled, prefer GNOME's gsettings but allow Cinnamon to work
      NIX_GSETTINGS_OVERRIDES_DIR = "/run/current-system/sw/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas";
    } else {}
  );

  # Resolve SSH askpass conflicts between KDE and GNOME
  # Prefer KDE's askpass when KDE is enabled, otherwise GNOME's
  programs.ssh.askPassword = lib.mkForce (
    if kdeEnabled then
      "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
    else if gnomeEnabled then
      "${pkgs.gnome-ssh-askpass}/libexec/seahorse/ssh-askpass"
    else
      ""
  );
}
