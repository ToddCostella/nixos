# Desktop Icons Configuration
# This module provides proper icons for Nix-installed applications

{ config, pkgs, ... }:

let
  # Icon set for the Herdr terminal entry below. Generated from ghostty's own
  # icon with a hue rotation (green instead of blue) so the two terminals are
  # instantly distinguishable at alt-tab / dash size while staying visibly the
  # same family of app. Sources live in modules/icons/herdr/.
  herdr-terminal-icon = pkgs.runCommand "herdr-terminal-icon" { } ''
    for sz in 16 32 48 64 128 256 512; do
      install -Dm644 ${./icons/herdr}/herdr-$sz.png \
        "$out/share/icons/hicolor/''${sz}x''${sz}/apps/com.mitchellh.ghostty.Herdr.png"
    done
  '';
in
{
  environment.systemPackages = with pkgs; [
    herdr-terminal-icon

    # Create desktop entries with proper icons for development tools
    
    # Lazygit - Git UI
    (makeDesktopItem {
      name = "lazygit";
      desktopName = "Lazygit";
      comment = "Terminal UI for Git commands";
      exec = "${lazygit}/bin/lazygit";
      icon = "git-gui";
      terminal = true;
      categories = [ "Development" "RevisionControl" ];
    })
    
    # Lazydocker - Docker UI
    (makeDesktopItem {
      name = "lazydocker";
      desktopName = "Lazydocker";
      comment = "Terminal UI for Docker";
      exec = "${lazydocker}/bin/lazydocker";
      icon = "docker";
      terminal = true;
      categories = [ "Development" "System" ];
    })
    
    # Neovim
    (makeDesktopItem {
      name = "neovim";
      desktopName = "Neovim";
      comment = "Vim-based text editor";
      exec = "${neovim}/bin/nvim %F";
      icon = "nvim";
      terminal = true;
      categories = [ "Utility" "TextEditor" ];
      mimeTypes = [ "text/plain" "text/x-script" ];
    })
    
    # WezTerm with custom icon
    (makeDesktopItem {
      name = "wezterm-custom";
      desktopName = "WezTerm";
      comment = "GPU-accelerated terminal emulator";
      exec = "${wezterm}/bin/wezterm";
      icon = "utilities-terminal";
      terminal = false;
      categories = [ "System" "TerminalEmulator" ];
    })
    
    # Httpie
    (makeDesktopItem {
      name = "httpie";
      desktopName = "HTTPie";
      comment = "Modern command-line HTTP client";
      exec = "${httpie}/bin/http";
      icon = "network-transmit-receive";
      terminal = true;
      categories = [ "Development" "Network" ];
    })
    
    # AWS CLI
    (makeDesktopItem {
      name = "aws-cli";
      desktopName = "AWS CLI";
      comment = "Amazon Web Services Command Line Interface";
      exec = "${awscli2}/bin/aws";
      icon = "network-server";
      terminal = true;
      categories = [ "Development" "Network" ];
    })
    
    # Claude Code with custom icon
    (makeDesktopItem {
      name = "claude-code-custom";
      desktopName = "Claude Code";
      comment = "AI-powered coding assistant";
      exec = "${claude-code}/bin/claude-code";
      icon = "applications-artificial-intelligence";
      terminal = true;
      categories = [ "Development" ];
    })
    
    # Obsidian (override to ensure proper icon)
    (makeDesktopItem {
      name = "obsidian-custom";
      desktopName = "Obsidian";
      comment = "Knowledge base and note-taking application";
      exec = "${obsidian}/bin/obsidian %u";
      icon = "obsidian";
      terminal = false;
      categories = [ "Office" "TextEditor" ];
    })
    
    # DBeaver (ensure proper icon)
    (makeDesktopItem {
      name = "dbeaver-custom";
      desktopName = "DBeaver";
      comment = "Universal SQL Client";
      exec = "${dbeaver-bin}/bin/dbeaver";
      icon = "dbeaver";
      terminal = false;
      categories = [ "Development" "Database" ];
    })
    
    # Arduino IDE (ensure proper icon)
    (makeDesktopItem {
      name = "arduino-ide-custom";
      desktopName = "Arduino IDE";
      comment = "Development environment for Arduino";
      exec = "${arduino-ide}/bin/arduino-ide";
      icon = "arduino-ide";
      terminal = false;
      categories = [ "Development" "Electronics" ];
    })
    
    # Bazecor (ensure proper icon)
    (makeDesktopItem {
      name = "bazecor-custom";
      desktopName = "Bazecor";
      comment = "Keyboard configurator for Dygma keyboards";
      exec = "${bazecor}/bin/bazecor";
      icon = "input-keyboard";
      terminal = false;
      categories = [ "Settings" "HardwareSettings" ];
    })
    
    # Pinta image editor
    (makeDesktopItem {
      name = "pinta-custom";
      desktopName = "Pinta";
      comment = "Simple image editor";
      exec = "${pinta}/bin/pinta %F";
      icon = "pinta";
      terminal = false;
      categories = [ "Graphics" "2DGraphics" "RasterGraphics" ];
      mimeTypes = [ "image/png" "image/jpeg" "image/gif" "image/bmp" ];
    })
    
    # Mu Editor
    (makeDesktopItem {
      name = "mu-editor";
      desktopName = "Mu Editor";
      comment = "Simple Python editor for beginners";
      exec = "${mu}/bin/mu-editor";
      icon = "applications-python";
      terminal = false;
      categories = [ "Development" "Education" ];
    })
    
    # LibreOffice components with proper icons
    (makeDesktopItem {
      name = "libreoffice-writer-custom";
      desktopName = "LibreOffice Writer";
      comment = "Word processor";
      exec = "${libreoffice}/bin/libreoffice --writer %U";
      icon = "libreoffice-writer";
      terminal = false;
      categories = [ "Office" "WordProcessor" ];
      mimeTypes = [ "application/vnd.oasis.opendocument.text" "application/msword" ];
    })
    
    (makeDesktopItem {
      name = "libreoffice-calc-custom";
      desktopName = "LibreOffice Calc";
      comment = "Spreadsheet application";
      exec = "${libreoffice}/bin/libreoffice --calc %U";
      icon = "libreoffice-calc";
      terminal = false;
      categories = [ "Office" "Spreadsheet" ];
      mimeTypes = [ "application/vnd.oasis.opendocument.spreadsheet" "application/vnd.ms-excel" ];
    })
    
    # --- Terminals: separate GNOME app-switcher identities ---
    # GNOME groups windows by app-id, matching a window's Wayland app-id against
    # a .desktop file's StartupWMClass. Every ghostty window reports the same
    # default app-id (com.mitchellh.ghostty), so bare-ghostty and herdr sessions
    # collapse into one icon. Passing --class gives herdr windows their own
    # app-id, and the matching StartupWMClass below makes GNOME treat them as a
    # separate application with its own icon and alt-tab entry.
    #
    # NOTE: ghostty's own stock entry (com.mitchellh.ghostty.desktop, shipped in
    # the package) still covers plain ghostty, so it is not redefined here.
    (makeDesktopItem {
      name = "ghostty-herdr";
      desktopName = "Herdr";
      comment = "Terminal workspace manager for AI coding agents (ghostty)";
      # NOTE: deliberately NOT ${herdr}. The herdr overlay is applied only inside
      # home-manager.users.todd (see flake.nix), so a system module like this one
      # resolves pkgs.herdr against plain nixpkgs — a different, older herdr
      # (0.7.5) than the 0.9.1 actually on your PATH. Launch via the login shell
      # so it picks up the home-manager profile's herdr, whatever version that is.
      exec = "${ghostty}/bin/ghostty --class=com.mitchellh.ghostty.Herdr -e ${pkgs.zsh}/bin/zsh -l -c herdr";
      icon = "com.mitchellh.ghostty.Herdr";
      terminal = false;
      categories = [ "System" "TerminalEmulator" "Development" ];
      startupWMClass = "com.mitchellh.ghostty.Herdr";
    })

    # Additional icon theme packages for better icon support
    papirus-icon-theme
    numix-icon-theme-circle
    hicolor-icon-theme
  ];
  
  # Configure XDG icon directories
  environment.pathsToLink = [ 
    "/share/icons"
    "/share/pixmaps"
  ];
  
  # Set default icon theme for GTK applications
  environment.variables = {
    GTK_ICON_THEME = "Papirus-Dark";
  };
  
  # Configure GNOME to use better icon theme
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.interface]
    icon-theme='Papirus-Dark'
  '';
}