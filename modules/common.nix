# Common NixOS configuration shared across all hosts.
# Headless-safe: no desktop, display server, audio, or virtualisation settings.
# Each host imports this and then adds its own specifics.

{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./remote-terminal.nix  # SSH + Mosh on every host
  ];

  # Nix settings
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "todd" ];
  };

  # Set NIX_PATH and registry to use flake inputs for reproducibility
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Time zone
  time.timeZone = "America/Vancouver";

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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Base user definition (headless defaults; host overrides extraGroups)
  users.users.todd = {
    isNormalUser = true;
    description = "Todd Costella";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };

  # Enable zsh system-wide (oh-my-zsh managed in home manager)
  programs.zsh.enable = true;

  # Enable Avahi for mDNS .local resolution
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    openFirewall = true;
  };

  # Limit journal size to save disk space
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month
  '';

  # Core programs available on every host
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;  # 1Password SSH agent handles SSH keys
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Default editor
  environment.variables.EDITOR = "nvim";

  # Core headless CLI packages
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    zip
    unzip

    # Network diagnostic tools
    dig
    traceroute
    nmap
    netcat
    iperf3
    mtr
    whois
    tcpdump
    inetutils
    net-tools
    iproute2
    dnsutils
    ldns
    socat
    iftop
    nethogs
    vnstat

    # System utilities
    btop
    jq
    ripgrep
    fd
    bc
    tree
  ];
}
