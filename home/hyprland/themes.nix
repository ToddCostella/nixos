# Omarchy-style colour palettes for the Hyprland session.
#
# Pick one with `desktop.theme` (see ./default.nix). Every themed component
# (Hyprland borders, Waybar, Mako, Walker, Hyprlock, the solid-colour
# background) reads from the selected palette, so switching is a one-line change
# plus a rebuild.
#
# Hex values only, no leading '#'. Roles:
#   bg       window/bar background        surface  raised background (inputs, popovers)
#   overlay  borders, inactive elements   muted    secondary text
#   fg       primary text                 accent   active border, highlights
#   accent2  gradient partner for accent  red/green/yellow  urgent / ok / warning
{
  tokyo-night = {
    bg = "1a1b26"; surface = "24283b"; overlay = "414868"; muted = "565f89";
    fg = "c0caf5"; accent = "7aa2f7"; accent2 = "bb9af7";
    red = "f7768e"; green = "9ece6a"; yellow = "e0af68";
  };

  catppuccin = {  # Mocha
    bg = "1e1e2e"; surface = "313244"; overlay = "45475a"; muted = "6c7086";
    fg = "cdd6f4"; accent = "89b4fa"; accent2 = "cba6f7";
    red = "f38ba8"; green = "a6e3a1"; yellow = "f9e2af";
  };

  gruvbox = {  # Dark
    bg = "282828"; surface = "3c3836"; overlay = "504945"; muted = "928374";
    fg = "ebdbb2"; accent = "fabd2f"; accent2 = "fe8019";
    red = "fb4934"; green = "b8bb26"; yellow = "fabd2f";
  };

  nord = {
    bg = "2e3440"; surface = "3b4252"; overlay = "4c566a"; muted = "616e88";
    fg = "eceff4"; accent = "88c0d0"; accent2 = "81a1c1";
    red = "bf616a"; green = "a3be8c"; yellow = "ebcb8b";
  };

  everforest = {  # Dark medium
    bg = "2d353b"; surface = "343f44"; overlay = "475258"; muted = "859289";
    fg = "d3c6aa"; accent = "a7c080"; accent2 = "83c092";
    red = "e67e80"; green = "a7c080"; yellow = "dbbc7f";
  };

  kanagawa = {  # Wave
    bg = "1f1f28"; surface = "2a2a37"; overlay = "54546d"; muted = "727169";
    fg = "dcd7ba"; accent = "7e9cd8"; accent2 = "957fb8";
    red = "c34043"; green = "98bb6c"; yellow = "e6c384";
  };
}
