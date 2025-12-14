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
      ./desktop-gnome.nix  # GNOME Desktop
    ];

  # Boot loader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "1";  # Use lower resolution for readable text on high-DPI displays

  # Networking
  networking.hostName = "nixos-dev"; # Define your hostname
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [
      networkmanager-openvpn  # For NordVPN OpenVPN connections
    ];
  };

  # Filesystem mounts
  fileSystems."/mnt/debian" = {
    device = "/dev/nvme0n1p2";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # Set your time zone
#  time.timeZone = "America/Vancouver"; 
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
  # Display Server and Display Manager
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;  # GDM works well with all desktop environments

  # Configure keymap for X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

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
    qt6.qtbase
    libxkbcommon
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

  # XDG portal configuration
  # Desktop-specific portals are configured in their respective modules
  xdg.portal = {
    enable = true;
    # extraPortals are added by desktop environment modules
  };
 
  # Enable CUPS to print documents
  services.printing.enable = true;

  # Enable Avahi for printer discovery and mDNS resolution
  services.avahi = {
    enable = true;
    nssmdns4 = true;  # Enable mDNS for IPv4 .local domain resolution
    nssmdns6 = true;  # Enable mDNS for IPv6 .local domain resolution
    openFirewall = true;  # Allow mDNS traffic through firewall
  };

  nixpkgs.config.allowUnfree = true;
 
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;  # Start Docker on boot
    autoPrune.enable = true;  # Automatic cleanup
  };

  # QEMU/KVM virtualization for Windows 11 with enhanced stability
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;  # TPM 2.0 emulation for Windows 11
      # OVMF (UEFI with Secure Boot and TPM support) is available by default
    };
    onBoot = "ignore";  # Don't auto-start VMs on boot
    onShutdown = "shutdown";  # Graceful shutdown
    parallelShutdown = 10;  # Shutdown timeout in seconds
  };

  # Enable nested virtualization and VM optimizations
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1
  '';

  # Enable IOMMU for better device passthrough support
  # usbcore.autosuspend=-1 fixes USB controller resume issues after suspend
  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" "usbcore.autosuspend=-1" ];

  # CPU governor for better VM performance
  powerManagement.cpuFreqGovernor = "performance";

  # Fix Dell XPS touchscreen not working after suspend/resume
  # Reloads the i2c-hid driver after resuming from sleep
  systemd.services.fix-touchscreen-resume = {
    description = "Reload i2c-hid after resume to fix touchscreen";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kmod}/bin/modprobe -r i2c_hid_acpi";
      ExecStartPost = "${pkgs.kmod}/bin/modprobe i2c_hid_acpi";
    };
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.todd = {
    isNormalUser = true;
    description = "Todd Costella";
    extraGroups = [ "networkmanager" "wheel" "docker" "dialout" "libvirtd" ];
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
    zip
    unzip
    hugo

    # Terminal utilities
    wezterm
    feh
    playerctl
    brightnessctl
    aerc            # Terminal email client
    
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
    yazi
    zoxide
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
    wireshark
    inetutils  # Provides ping, telnet, etc.
    net-tools  # Provides netstat, ifconfig, etc.
    iproute2   # Modern networking tools (ip, ss, etc.)
    dnsutils   # DNS utilities including dig, nslookup
    ldns       # DNS tools including drill
    socat      # Multipurpose network relay
    iftop      # Network bandwidth monitor
    nethogs    # Per-process network bandwidth monitor
    vnstat     # Network traffic monitor
    mitmproxy  # HTTP/HTTPS traffic interception proxy for debugging

    # VPN tools
    openvpn    # OpenVPN client for NordVPN manual configuration
    wgnord     # Unofficial NordVPN WireGuard client
    
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

    # Virtualization tools
    gnome-boxes       # Simple and stable VM management (replaces virt-manager)
    virt-viewer       # VM display viewer
    spice-gtk         # SPICE client for VM access
    virtio-win        # Windows virtio drivers ISO
    qemu              # Full QEMU suite for advanced features
    OVMFFull          # UEFI firmware with Secure Boot support for VMs
    swtpm             # TPM 2.0 emulator for Windows 11 support
    samba             # For shared folders between host and VM
    
    # NPM comes with nodejs_24, yarn for alternative package management
    yarn
    
    # AWS CDK for infrastructure as code
    nodePackages.aws-cdk
    
    # Image editor
    pinta

    # SVG tools
    librsvg  # Provides rsvg-convert for SVG to PNG/PDF conversion

    # Markdown editor
    apostrophe

    # Keyboard configurator for Dygma keyboards
    bazecor
    
    # Arduino IDE for microcontroller development
    arduino-ide
    
    # Mu editor - simple Python editor for beginners and microcontrollers
    mu
    
    # Bluetooth utilities
    bluez
    bluez-tools

    # Universal screenshot utilities (work across all DEs)
    grim             # Wayland screenshot utility
    slurp            # Wayland area selection
    swappy           # Wayland screenshot editor with markup
    wl-clipboard     # Wayland clipboard utilities
    ksnip            # Advanced screenshot tool with annotation features
    
    # Custom screenshot scripts
    # SIMPLE SOLUTION: PrintScreen saves to ~/dev/buoyancy-platform/tmp/current-screenshot.png (static filename)
    # Just reference ~/dev/buoyancy-platform/tmp/current-screenshot.png in Claude Code - no special key pasting needed!

    # PrintScreen: Save to static filename AND copy to clipboard
    (pkgs.writeShellScriptBin "screenshot-area" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      gnome-screenshot -a -f ~/dev/buoyancy-platform/tmp/current-screenshot.png && \
      ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < ~/dev/buoyancy-platform/tmp/current-screenshot.png && \
      echo "Screenshot saved to ~/dev/buoyancy-platform/tmp/current-screenshot.png and copied to clipboard"
    '')

    (pkgs.writeShellScriptBin "screenshot-area-file" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      gnome-screenshot -a -f ~/dev/buoyancy-platform/tmp/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
    '')

    (pkgs.writeShellScriptBin "screenshot-full" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      SCREENSHOT_FILE=~/dev/buoyancy-platform/tmp/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
      gnome-screenshot -f "$SCREENSHOT_FILE" && \
      ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$SCREENSHOT_FILE" && \
      echo "Screenshot saved to $SCREENSHOT_FILE and copied to clipboard"
    '')

    (pkgs.writeShellScriptBin "screenshot-full-file" ''
      mkdir -p ~/Pictures/Screenshots
      gnome-screenshot -f ~/Pictures/Screenshots/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
    '')

    (pkgs.writeShellScriptBin "screenshot-window" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      SCREENSHOT_FILE=~/dev/buoyancy-platform/tmp/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
      gnome-screenshot -w -f "$SCREENSHOT_FILE" && \
      ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$SCREENSHOT_FILE" && \
      echo "Screenshot saved to $SCREENSHOT_FILE and copied to clipboard"
    '')

    (pkgs.writeShellScriptBin "screenshot-window-file" ''
      mkdir -p ~/Pictures/Screenshots
      gnome-screenshot -w -f ~/Pictures/Screenshots/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png
    '')

    # Helper to get the most recent screenshot path for easy Claude Code pasting
    (pkgs.writeShellScriptBin "screenshot-latest" ''
      LATEST=$(ls -t ~/dev/buoyancy-platform/tmp/screenshot-*.png 2>/dev/null | head -1)
      if [ -n "$LATEST" ]; then
        echo "$LATEST"
        echo "$LATEST" | ${pkgs.wl-clipboard}/bin/wl-copy
        echo "(Path copied to clipboard - paste with Ctrl+Shift+V)"
      else
        echo "No screenshots found in ~/dev/buoyancy-platform/tmp/"
      fi
    '')

    # mitmproxy helper for capturing localhost HTTP traffic during React development
    # Usage: mitm-localhost [output-file]
    # Default output: network.log in current directory
    (pkgs.writeShellScriptBin "mitm-localhost" ''
      OUTPUT_FILE="''${1:-network.log}"
      echo "Starting mitmproxy to capture localhost traffic..."
      echo "Output file: $OUTPUT_FILE"
      echo ""
      echo "Firefox setup required:"
      echo "  1. Set HTTP proxy to 127.0.0.1:8080 in Firefox Network Settings"
      echo "  2. In about:config, set network.proxy.allow_hijacking_localhost = true"
      echo ""
      echo "Press Ctrl+C to stop capturing"
      echo "---"
      ${pkgs.mitmproxy}/bin/mitmdump --set flow_detail=2 --showhost "~d localhost" 2>&1 | tee "$OUTPUT_FILE"
    '')

    # Wezterm clipboard-to-path converter for Claude Code image pasting
    # Similar to Kitty's clip2path solution
    (pkgs.writeShellScriptBin "wezterm-clip2path" ''
      #!/usr/bin/env bash

      # Get the pane ID from environment or argument
      PANE_ID="''${1:-$WEZTERM_PANE}"

      # Check if clipboard contains an image
      MIME_TYPE=$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null | grep -E "^image/" | head -1)

      if [ -n "$MIME_TYPE" ]; then
        # Extract file extension from MIME type (e.g., image/png -> png)
        EXT="''${MIME_TYPE#image/}"

        # Create temp file with timestamp
        TEMP_FILE="/tmp/claude-clipboard-$(date +%Y%m%d-%H%M%S).''${EXT}"

        # Save image from clipboard to temp file
        ${pkgs.wl-clipboard}/bin/wl-paste --type "$MIME_TYPE" > "$TEMP_FILE"

        # Send the file path to the specified pane
        if [ -n "$PANE_ID" ]; then
          ${pkgs.wezterm}/bin/wezterm cli send-text --pane-id "$PANE_ID" --no-paste "$TEMP_FILE"
        else
          # Fallback: send to current pane
          ${pkgs.wezterm}/bin/wezterm cli send-text --no-paste "$TEMP_FILE"
        fi
      else
        # No image in clipboard, return failure so wezterm does normal paste
        exit 1
      fi
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
    noto-fonts-color-emoji
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

  # Disable GNOME Tracker (file indexer) - was failing repeatedly
  services.gnome.localsearch.enable = false;
  services.gnome.tinysparql.enable = false;

  # Limit journal size to save disk space
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month
  '';

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

  # Enable dconf for virt-manager settings
  programs.dconf.enable = true;

  # Environment variables for npm global packages and Wayland support
  environment.variables = {
    PATH = [ "$HOME/.npm-packages/bin" ];
    QT_QPA_PLATFORM = "wayland;xcb";  # Enable Wayland support for Qt apps
    EDITOR = "nvim";  # Default editor for yazi and other programs
  };


}
