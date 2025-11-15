# NixOS Configuration for Development Environment
# Edit this file at /etc/nixos/configuration.nix

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      # ./hardware-configuration.nix  # Not needed for WSL
      ./esp32-dev.nix  # ESP32 development configuration
    ];

  # WSL-specific: Boot loader not needed
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos-wsl"; # Define your hostname
  # WSL handles networking, but we keep networkmanager for compatibility
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
  
  # Enable nix-ld for running dynamically linked executables
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    curl
    expat
    libuuid
    libusb1
    libxcrypt
    libxcrypt-legacy
    systemd
    zlib
  ];


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
    wget
    unzip
    hugo

    # Development tools
    docker-compose
    awscli2
    lazygit
    lazydocker
    
    # Python tools
    uv
    
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
    
    # Network diagnostic tools
    dig
    traceroute
    nmap
    netcat
    iperf3
    mtr
    whois
    tcpdump
    inetutils  # Provides ping, telnet, etc.
    net-tools  # Provides netstat, ifconfig, etc.
    iproute2   # Modern networking tools (ip, ss, etc.)
    dnsutils   # DNS utilities including dig, nslookup
    ldns       # DNS tools including drill
    socat      # Multipurpose network relay
    iftop      # Network bandwidth monitor
    nethogs    # Per-process network bandwidth monitor
    vnstat     # Network traffic monitor

    # VPN tools
    openvpn    # OpenVPN client for NordVPN manual configuration

    nodejs_24
    # AI
    claude-code

    # NPM comes with nodejs_24, yarn for alternative package management
    yarn
    
    # AWS CDK for infrastructure as code
    nodePackages.aws-cdk

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

  };


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

  # Nix settings
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Set NIX_PATH for nixos-rebuild
  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs"
    "nixos-config=/etc/nixos/configuration.nix"
  ];

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

  # Environment variables for npm global packages
  environment.variables = {
    PATH = [ "$HOME/.npm-packages/bin" ];
  };


}
