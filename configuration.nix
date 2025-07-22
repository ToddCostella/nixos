# NixOS Configuration for Development Environment
# Edit this file at /etc/nixos/configuration.nix

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Boot loader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos-dev"; # Define your hostname
  networking.networkmanager.enable = true;

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
  programs.sway = {
  	enable = true;
	wrapperFeatures.gtk = true;
	extraPackages = with pkgs; [
		swaylock
		swayidle
		wl-clipboard
		mako
		wofi
		waybar
		grim
		slurp
		wf-recorder
		kanshi
	];
  };

  services.gnome.gnome-keyring.enable = true;
  
  # Enable PAM integration for keyring
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sway.enableGnomeKeyring = true;

  xdg.portal = {
  	enable = true;
	wlr.enable = true;
	extraPortals = [pkgs.xdg-desktop-portal-gtk];
	};
 
  # Enable CUPS to print documents
  services.printing.enable = true;
  nixpkgs.config.allowUnfree = true;
 
 virtualisation.docker = {
    enable = true;
    enableOnBoot = true;  # Start Docker on boot
    autoPrune.enable = true;  # Automatic cleanup
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.todd = {
    isNormalUser = true;
    description = "Todd Costella";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };


# Core development tools
   environment.systemPackages = with pkgs;[
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
    docker
    docker-compose
    awscli2
    lazygit
    lazydocker
    
    # Database tools
    dbeaver-bin
    
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
    # (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "Hack" "SourceCodePro" ]; })
    
    # Build tools
    gcc
    gnumake
    pkg-config
    
    # Additional utilities
    ripgrep
    fd
    bat
    tree
    tmux
    
    # Firefox browser
    firefox

    nodejs_24
  ];

  # Programs configuration
  programs = {
    # Enable zsh system-wide
    zsh = {
      enable = true;
      ohMyZsh = {
        enable = true;
        plugins = [ "git" "docker" "docker-compose" "aws" ];
        theme = "robbyrussell";
      };
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
  #fonts.packages = with pkgs; [
  #  noto-fonts-cjk
  #  noto-fonts-emoji
  #  liberation_ttf
  #  fira-code
  #  fira-code-symbols
  #];

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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did not change this!
  # xdg.portal.enable = true;

  # Additional configuration for specific tools

  # JetBrains Toolbox - needs to be installed manually or via overlay
  # You can download it from: https://www.jetbrains.com/toolbox-app/
  
  # Rainfrog - needs to be built from source or added as a custom package
  # For now, you can install it manually after system setup

  # Post-installation commands to run after first boot:
  # 1. Install JetBrains Toolbox manually
  # 2. Install Pika Backup via Flatpak: flatpak install flathub org.gnome.World.PikaBackup
  # 3. Install rainfrog manually or build from source
  # 4. Configure i3 in ~/.config/i3/config

}
