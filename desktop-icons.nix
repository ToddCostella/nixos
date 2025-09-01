# Desktop Icons Configuration
# This module provides proper icons for Nix-installed applications

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
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