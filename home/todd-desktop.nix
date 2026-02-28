# Home Manager desktop packages for todd — GUI apps only.
# Imported only for hosts with a desktop environment (e.g. nixos-dev).
# Headless-safe packages are in todd-base.nix.

{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    slack
    obsidian
    signal-desktop
    zoom-us
    figma-linux
    dbeaver-bin
    bcompare
    wezterm
    aerc
    hugo
    dropbox
    pinta
    apostrophe
    rainfrog
  ];
}
