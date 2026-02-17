# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS system configuration repository for a development environment on a Dell XPS laptop (hostname: `nixos-dev`). It contains declarative system configuration files that define the entire system state, including packages, services, and user settings.

## Architecture

- `configuration.nix` - Main NixOS configuration file containing system settings, user accounts, packages, and services
- `hardware-configuration.nix` - Auto-generated hardware-specific configuration (do not modify manually)
- `remote-terminal.nix` - Remote terminal access: tmux + mosh + SSH hardening
- `desktop-gnome.nix` - GNOME desktop environment configuration
- `desktop-cosmic.nix` - COSMIC desktop environment (System76, alpha)
- `desktop-icons.nix` - Custom desktop application icons
- `playwright-dev.nix` - Playwright E2E testing dependencies (system libraries for Chromium)
- `esp32-dev.nix` - ESP32 microcontroller development tools
- `photo-restoration.nix` - Photo editing and restoration applications

## Key System Components

- **Hostname**: `nixos-dev` (accessible as `nixos-dev.local` via mDNS on local network)
- **Desktop**: GNOME (primary) + COSMIC (available at login screen); display manager is GDM
- **Terminal**: WezTerm (default), with tmux for session management
- **Shell**: zsh with oh-my-zsh (theme: robbyrussell)
- **Window Manager**: GNOME (Wayland); Sway references in old docs are outdated
- **Virtualization**: Docker (auto-start on boot) + QEMU/KVM/libvirtd with nested virtualization enabled
- **Audio**: PipeWire (ALSA, PulseAudio compat, JACK)
- **User**: Primary user "todd" — groups: networkmanager, wheel, docker, dialout, libvirtd

## Key Development Tools

- **Languages/Runtimes**: Node.js 24, Python (uv), gcc, yarn, npm
- **AI**: claude-code
- **Editors**: neovim, apostrophe (markdown)
- **Git**: lazygit, gh (GitHub CLI)
- **Docker**: lazydocker, docker-compose
- **Database**: dbeaver-bin, postgresql (psql client), rainfrog
- **Search**: ripgrep, fd, fzf, bat
- **File manager**: yazi (with zoxide integration)
- **Navigation**: zoxide, atuin (shell history)
- **Network/Debugging**: mitmproxy, wireshark, nmap, iperf3, mtr, and many more
- **Cloud**: awscli2, aws-cdk
- **VPN**: openvpn, wgnord (NordVPN)
- **Browsers**: Firefox, Google Chrome, Zen Browser (AppImage)
- **Productivity**: obsidian, dropbox, 1password-gui, figma-linux, slack, signal-desktop, zoom-us
- **Hardware**: bazecor (Dygma keyboards), arduino-ide, mu editor

## tmux Configuration (remote-terminal.nix)

- **Prefix**: `Alt-a` (M-a)
- **Theme**: Catppuccin Mocha (rounded window status)
- **Plugins**: sensible, yank, resurrect, continuum, catppuccin, tmux-sessionx
- **Session restore**: continuum auto-save every 15 min, auto-restore on start
- **Session switcher**: tmux-sessionx bound to `o`, zoxide mode enabled
- **Key bindings**: Alt+number (window switch), Alt+arrows (pane nav), `|`/`-` (split)
- **Clipboard**: wl-copy (Wayland)

## Screenshot Tools

Custom shell scripts installed as system packages:
- `screenshot-area` - Area selection with Satty annotation
- `screenshot-full` - Full screen with Satty annotation
- `screenshot-window` - Window capture with Satty annotation
- `screenshot-quick` - Quick area capture, no annotation
- Output saved to: `~/dev/buoyancy-platform/tmp/current-screenshot.png`

## Custom Shell Scripts

- `wezterm-clip2path` - Converts clipboard image to file path for Claude Code image pasting
- `mitm-localhost` - mitmproxy helper for capturing localhost HTTP traffic during development

## Network & Firewall

- Open TCP ports: 3000 (Vite dev server), 8080 (WebSocket backend / mitmproxy)
- mDNS enabled via Avahi (`nixos-dev.local`)
- SSH: key-only auth, no root login, allows user `todd`
- Mosh: enabled (auto-opens UDP 60000-61000)

## Common Commands

### System Management
```bash
# Apply configuration changes (requires sudo)
sudo nixos-rebuild switch

# Test configuration without making it default
sudo nixos-rebuild test

# Dry-run to check for syntax errors
sudo nixos-rebuild dry-build

# Rollback to previous generation
sudo nixos-rebuild rollback
```

### Git Operations
Git is pre-configured system-wide:
- Name: Todd Costella
- Email: ToddCostella@gmail.com
- Default branch: main

## Development Workflow

1. Make changes to the relevant `.nix` file
2. Test with `sudo nixos-rebuild dry-build` to check syntax
3. Apply with `sudo nixos-rebuild switch`
4. Commit changes to git after successful application

## Important Notes

- Never modify `hardware-configuration.nix` manually — it's auto-generated
- System packages are declared in `environment.systemPackages` in `configuration.nix`
- SSH is configured in `remote-terminal.nix`, not `configuration.nix`
- The Debian partition is mounted read-only at `/mnt/debian` (nvme0n1p2)
- Nix flakes and nix-command experimental features are enabled
- Weekly garbage collection removes generations older than 30 days
- Journal capped at 500MB / 1 month retention
- GNOME Tracker (localsearch/tinysparql) is disabled
