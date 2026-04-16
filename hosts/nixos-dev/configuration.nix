# NixOS Configuration for nixos-dev (Dell XPS laptop)
# Laptop/desktop-specific settings. Shared config is in modules/common.nix.

{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/esp32-dev.nix
    ../../modules/photo-restoration.nix
    ../../modules/desktop-icons.nix
    ../../modules/desktop-gnome.nix
    # ../../modules/desktop-cosmic.nix  # COSMIC Desktop — not available in current nixpkgs
    ../../modules/playwright-dev.nix
  ];

  # Boot loader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "1";  # Lower resolution for readable text on high-DPI displays

  # Enable nested virtualization and VM optimizations
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1
  '';

  # Enable IOMMU for better device passthrough support
  # usbcore.autosuspend=-1 fixes USB controller resume issues after suspend
  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" "usbcore.autosuspend=-1" ];

  # Networking
  networking.hostName = "nixos-dev";
  networking.nameservers = [ "10.0.0.8" "1.1.1.1" ];  # AdGuard Home, Cloudflare fallback
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

  # Display Server and Display Manager
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;

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
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxkbfile
    libxshmfence
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
  xdg.portal = {
    enable = true;
    # extraPortals are added by desktop environment modules
  };

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  # QEMU/KVM virtualization for Windows 11 with enhanced stability
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
    parallelShutdown = 10;
  };

  # CPU governor for better VM performance
  powerManagement.cpuFreqGovernor = "performance";

  # Fix Dell XPS touchscreen not working after suspend/resume
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

  # Full user group list for laptop (overrides common.nix extraGroups)
  users.users.todd.extraGroups = [ "networkmanager" "wheel" "docker" "dialout" "libvirtd" ];

  # Disable GNOME Tracker (file indexer) - was failing repeatedly
  services.gnome.localsearch.enable = false;
  services.gnome.tinysparql.enable = false;

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

  # fwupd - Firmware update daemon for Dell and other hardware
  services.fwupd.enable = true;

  # Open ports in the firewall
  networking.firewall.allowedTCPPorts = [ 3000 8080 ];  # Vite dev server + WebSocket backend

  # 1Password — use NixOS module for polkit integration
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "todd" ];
  };

  # Enable Firefox
  programs.firefox.enable = true;

  # Enable npm
  programs.npm = {
    enable = true;
    npmrc = ''
      prefix = ''${HOME}/.npm-packages
    '';
  };

  # Enable dconf for virt-manager settings
  programs.dconf.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
  ];

  # Environment variables for npm global packages and Wayland support
  environment.variables = {
    PATH = [ "$HOME/.npm-packages/bin" ];
    QT_QPA_PLATFORM = "wayland;xcb";
    EDITOR = "nvim";
  };

  # Desktop and laptop packages
  environment.systemPackages = with pkgs; [
    # Terminal utilities
    feh
    playerctl
    brightnessctl

    # Development tools
    docker-compose
    awscli2

    # AWS TUI tools
    claws
    e1s

    # Database tools
    postgresql

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
    direnv
    zsh-vi-mode

    # VPN tools
    openvpn
    wgnord

    # Browsers
    firefox
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
    gnome-boxes
    virt-viewer
    spice-gtk
    virtio-win
    qemu
    OVMFFull
    swtpm
    samba

    # Package management
    yarn
    aws-cdk-cli

    # SVG tools
    librsvg

    # Document conversion and LaTeX
    pandoc
    texlive.combined.scheme-medium

    # Keyboard configurator for Dygma keyboards
    bazecor

    # Arduino IDE for microcontroller development
    arduino-ide

    # Mu editor - simple Python editor for beginners and microcontrollers
    mu

    # Bluetooth utilities
    bluez
    bluez-tools

    # Screenshot utilities
    satty
    wl-clipboard

    # Area screenshot with Satty annotation
    (pkgs.writeShellScriptBin "screenshot-area" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      TMPFILE=$(mktemp /tmp/screenshot-XXXXXX.png)
      gnome-screenshot -a -f "$TMPFILE" && \
        ${pkgs.satty}/bin/satty -f "$TMPFILE" \
        --output-filename ~/dev/buoyancy-platform/tmp/current-screenshot.png \
        --copy-command "${pkgs.wl-clipboard}/bin/wl-copy"
      rm -f "$TMPFILE"
    '')

    # Full screen screenshot with Satty annotation
    (pkgs.writeShellScriptBin "screenshot-full" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      TMPFILE=$(mktemp /tmp/screenshot-XXXXXX.png)
      gnome-screenshot -f "$TMPFILE" && \
        ${pkgs.satty}/bin/satty -f "$TMPFILE" \
        --output-filename ~/dev/buoyancy-platform/tmp/current-screenshot.png \
        --copy-command "${pkgs.wl-clipboard}/bin/wl-copy"
      rm -f "$TMPFILE"
    '')

    # Window screenshot with Satty annotation
    (pkgs.writeShellScriptBin "screenshot-window" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      TMPFILE=$(mktemp /tmp/screenshot-XXXXXX.png)
      gnome-screenshot -w -f "$TMPFILE" && \
        ${pkgs.satty}/bin/satty -f "$TMPFILE" \
        --output-filename ~/dev/buoyancy-platform/tmp/current-screenshot.png \
        --copy-command "${pkgs.wl-clipboard}/bin/wl-copy"
      rm -f "$TMPFILE"
    '')

    # Quick area screenshot (no annotation)
    (pkgs.writeShellScriptBin "screenshot-quick" ''
      mkdir -p ~/dev/buoyancy-platform/tmp
      gnome-screenshot -a -f ~/dev/buoyancy-platform/tmp/current-screenshot.png && \
      ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < ~/dev/buoyancy-platform/tmp/current-screenshot.png
    '')

    # mitmproxy helper for capturing localhost HTTP traffic
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
    (pkgs.writeShellScriptBin "wezterm-clip2path" ''
      #!/usr/bin/env bash

      PANE_ID="''${1:-$WEZTERM_PANE}"

      MIME_TYPE=$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null | grep -E "^image/" | head -1)

      if [ -n "$MIME_TYPE" ]; then
        EXT="''${MIME_TYPE#image/}"
        TEMP_FILE="/tmp/claude-clipboard-$(date +%Y%m%d-%H%M%S).''${EXT}"
        ${pkgs.wl-clipboard}/bin/wl-paste --type "$MIME_TYPE" > "$TEMP_FILE"

        if [ -n "$PANE_ID" ]; then
          ${pkgs.wezterm}/bin/wezterm cli send-text --pane-id "$PANE_ID" --no-paste "$TEMP_FILE"
        else
          ${pkgs.wezterm}/bin/wezterm cli send-text --no-paste "$TEMP_FILE"
        fi
      else
        exit 1
      fi
    '')

    # mitmproxy for network traffic interception
    mitmproxy

    # wireshark for network analysis
    wireshark
  ];

  # Specialisations — alternative desktop environments selectable at boot or runtime.
  # Boot: systemd-boot shows entries like "NixOS - specialisation: Hyprland"
  # Runtime switch: sudo /run/current-system/specialisation/<name>/bin/switch-to-configuration switch
  # Back to default (GNOME): sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev
  specialisation = {

    hyprland.configuration = {
      system.nixos.tags = [ "Hyprland" ];
      services.desktopManager.gnome.enable = lib.mkForce false;
      services.gnome.gnome-keyring.enable = lib.mkForce false;
      services.gnome.gnome-online-accounts.enable = lib.mkForce false;
      security.pam.services.gdm.enableGnomeKeyring = lib.mkForce false;
      xdg.portal.extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-hyprland ];
      programs.hyprland.enable = true;
      programs.hyprland.xwayland.enable = true;
      environment.systemPackages = with pkgs; [
        waybar
        wofi
        hyprpaper
        hypridle
        hyprlock
        hyprshot
        wl-clipboard
        dunst
        kitty
      ];
      environment.variables = {
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
      };
    };

    cosmic.configuration = {
      system.nixos.tags = [ "COSMIC" ];
      services.desktopManager.gnome.enable = lib.mkForce false;
      services.gnome.gnome-keyring.enable = lib.mkForce false;
      services.gnome.gnome-online-accounts.enable = lib.mkForce false;
      security.pam.services.gdm.enableGnomeKeyring = lib.mkForce false;
      xdg.portal.extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-cosmic ];
      services.desktopManager.cosmic.enable = true;
      environment.systemPackages = with pkgs; [
        cosmic-files
        cosmic-edit
        cosmic-term
        cosmic-store
        cosmic-screenshot
        wl-clipboard
      ];
    };

    kde.configuration = {
      system.nixos.tags = [ "KDE-Plasma-6" ];
      services.desktopManager.gnome.enable = lib.mkForce false;
      services.gnome.gnome-keyring.enable = lib.mkForce false;
      services.gnome.gnome-online-accounts.enable = lib.mkForce false;
      security.pam.services.gdm.enableGnomeKeyring = lib.mkForce false;
      xdg.portal.extraPortals = lib.mkForce [ pkgs.kdePackages.xdg-desktop-portal-kde ];
      services.desktopManager.plasma6.enable = true;
      environment.variables = {
        TERMINAL = "wezterm";
      };
      environment.systemPackages = with pkgs; [
        kdePackages.kate
        kdePackages.konsole
        kdePackages.dolphin
        kdePackages.ark
        kdePackages.gwenview
        kdePackages.okular
        kdePackages.spectacle
        kdePackages.kalk
        kdePackages.kcalc
        kdePackages.kfind
        kdePackages.filelight
        kdePackages.partitionmanager
        kdePackages.kcolorchooser
      ];
    };

  };

  system.stateVersion = "24.05";
}
