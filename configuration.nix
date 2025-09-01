# NixOS Configuration for Development Environment
# Edit this file at /etc/nixos/configuration.nix

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./esp32-dev.nix  # ESP32 development configuration
      ./photo-restoration.nix
      ./desktop-icons.nix  # Custom desktop icons for Nix applications
    ];

  # Boot loader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos-dev"; # Define your hostname
  networking.networkmanager.enable = true;

  # Filesystem mounts
  fileSystems."/mnt/debian" = {
    device = "/dev/nvme0n1p2";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # Set your time zone
  time.timeZone = "America/Vancouver"; # Adjust for your location

  # Internationalization properties
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  # Enable GNOME desktop environment
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  
  
  # Configure keymap for X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.gnome.gnome-keyring.enable = true;
  
  # Enable PAM integration for keyring
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.gdm.enableGnomeKeyring = true;
  
  # Enable Polkit for authentication dialogs
  security.polkit.enable = true;
  
  # Enable D-Bus for inter-process communication
  services.dbus.enable = true;
  
  # Enable nix-ld for running dynamically linked executables
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    fuse3
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libappindicator-gtk3
    libdrm
    libnotify
    libpulseaudio
    libuuid
    libusb1
    libxcrypt
    libxcrypt-legacy
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.libxkbfile
    xorg.libxshmfence
    mesa
    nspr
    nss
    pango
    pipewire
    systemd
    zlib
    libsecret
  ];
  
  # Enable the secret storage service
  services.gnome.gnome-online-accounts.enable = true;

  # XDG portal configuration for GNOME
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };
 
  # Enable CUPS to print documents
  services.printing.enable = true;
  nixpkgs.config.allowUnfree = true;
 
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;  # Start Docker on boot
    autoPrune.enable = true;  # Automatic cleanup
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.todd = {
    isNormalUser = true;
    description = "Todd Costella";
    extraGroups = [ "networkmanager" "wheel" "docker" "dialout" ];
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };


# Core development tools
   environment.systemPackages = with pkgs;[
    # Development tools
    git
    neovim
    htop
    zsh
    oh-my-zsh
    curl
    wget
    unzip
    
    # Terminal utilities
    wezterm
    feh
    playerctl
    brightnessctl
    
    # Development tools
    docker-compose
    awscli2
    lazygit
    lazydocker
    
    # Database tools
    dbeaver-bin
    
    # Diff/merge tools
    bcompare

    # Communication apps
    slack
    signal-desktop
    zoom-us
    
    # Productivity apps
    obsidian
    dropbox
    _1password-gui
    
    # Python tools
    uv
    
    # Fonts
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
    nerd-fonts.sauce-code-pro
    
    # Build tools
    gcc
    gnumake
    pkg-config
    
    # Additional utilities
    ripgrep
    fd
    bat
    tree
    jq
    yq-go
    httpie
    direnv
    atuin
    fzf
    zsh-vi-mode
    
    # Firefox browser
    firefox
    
    # Chrome browser
    google-chrome
    
    # Zen browser - Privacy-focused Firefox-based browser
    (pkgs.appimageTools.wrapType2 {
      pname = "zen-browser";
      name = "zen-browser";
      version = "1.15.2b";
      src = pkgs.fetchurl {
        url = "https://github.com/zen-browser/desktop/releases/download/1.15.2b/zen-x86_64.AppImage";
        sha256 = "1g9c33gi2aa71x66k3xfr4gfcz7x01i56dxavxzzf0hija2w8dch";
      };
      extraInstallCommands = ''
        mkdir -p $out/share/applications
        cat > $out/share/applications/zen-browser.desktop <<EOF
        [Desktop Entry]
        Name=Zen Browser
        Comment=Experience tranquil browsing
        Exec=zen-browser %U
        Terminal=false
        Type=Application
        Icon=zen-browser
        Categories=Network;WebBrowser;
        MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
        StartupNotify=true
        EOF
      '';
    })

    nodejs_24
    # AI 
    claude-code
    
    # NPM comes with nodejs_24, yarn for alternative package management
    yarn
    
    # AWS CDK for infrastructure as code
    nodePackages.aws-cdk
    
    # Image editor
    pinta
    
    # Keyboard configurator for Dygma keyboards
    bazecor
    
    # Arduino IDE for microcontroller development
    arduino-ide
    
    # Mu editor - simple Python editor for beginners and microcontrollers
    mu
    
    # Bluetooth utilities
    bluez
    bluez-tools
    
    # Credential storage for IDEs
    libsecret
    
    # GNOME extensions
    gnomeExtensions.forge
    gnomeExtensions.workspace-indicator
    
    # GNOME utilities
    gnome-tweaks
    
    # Office suite
    libreoffice
    
    # Screenshot utilities
    gnome-screenshot  # GNOME's native screenshot tool
    grim             # Wayland screenshot utility
    slurp            # Wayland area selection
    swappy           # Wayland screenshot editor with markup
    wl-clipboard     # Wayland clipboard utilities
    
    # Custom screenshot scripts
    (pkgs.writeShellScriptBin "screenshot-area" ''
      mkdir -p ~/Pictures/Screenshots
      gnome-screenshot -a -f ~/dev/buoyancy-platform/tmp/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
    '')
    
    (pkgs.writeShellScriptBin "screenshot-full" ''
      mkdir -p ~/Pictures/Screenshots  
      gnome-screenshot -f ~/Pictures/Screenshots/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
    '')
    
    (pkgs.writeShellScriptBin "screenshot-window" ''
      mkdir -p ~/Pictures/Screenshots
      gnome-screenshot -w -f ~/Pictures/Screenshots/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
    '')
  ];

  # Programs configuration
  programs = {
    # Enable zsh system-wide
    zsh = {
      enable = true;
      ohMyZsh = {
        enable = true;
        plugins = [ "git" "docker" "docker-compose" "aws" "vi-mode" "fzf" ];
        theme = "robbyrussell";
      };
    };
    
    # Enable npm
    npm = {
      enable = true;
      npmrc = ''
        prefix = ''${HOME}/.npm-packages
      '';
    };

    # Git configuration
    git = {
      enable = true;
      config = {
        user = {
          name = "Todd Costella";
          email = "ToddCostella@gmail.com";
        };
        init.defaultBranch = "main";
      };
    };

    # Enable Firefox
    firefox.enable = true;
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  
  # Enable PipeWire for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  
  # Disable PulseAudio since we're using PipeWire
  services.pulseaudio.enable = false;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Nix settings
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did not change this!
  # xdg.portal.enable = true;

  # Enable direnv for development environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Environment variables for npm global packages and Wayland support
  environment.variables = {
    PATH = [ "$HOME/.npm-packages/bin" ];
    QT_QPA_PLATFORM = "wayland;xcb";  # Enable Wayland support for Qt apps
  };


}
