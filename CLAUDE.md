# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS system configuration repository for a development environment. It contains declarative system configuration files that define the entire system state, including packages, services, and user settings.

## Architecture

- `configuration.nix` - Main NixOS configuration file containing system settings, user accounts, packages, and services
- `hardware-configuration.nix` - Auto-generated hardware-specific configuration (do not modify manually)
- `playwright-dev.nix` - Playwright E2E testing dependencies module (system libraries for Chromium)
- `esp32-dev.nix` - ESP32 microcontroller development tools
- `photo-restoration.nix` - Photo editing and restoration applications
- `desktop-gnome.nix` - GNOME desktop environment configuration
- `desktop-icons.nix` - Custom desktop application icons
- The configuration is designed for a development-focused desktop environment using GNOME

## Key System Components

- **Window Manager**: Sway with supporting tools (swaylock, waybar, wofi, etc.)
- **Development Environment**: Comprehensive setup with Docker, Node.js 24, Python (uv), Git, and development tools
- **User Setup**: Primary user "todd" with docker group membership and zsh shell
- **Development Tools**: Includes lazygit, lazydocker, dbeaver, ripgrep, fd, bat, neovim, claude-code

## Common Commands

### System Management
```bash
# Apply configuration changes (requires sudo)
sudo nixos-rebuild switch

# Test configuration without making it default
sudo nixos-rebuild test

# Build configuration without switching
sudo nixos-rebuild build

# Rollback to previous generation
sudo nixos-rebuild rollback
```

### Configuration Testing
Always test configuration changes before committing:
```bash
# Dry-run to check for syntax errors
sudo nixos-rebuild dry-build
```

### Git Operations
Git is pre-configured with user details:
- Name: Todd Costella
- Email: ToddCostella@gmail.com
- Default branch: main

## Development Workflow

1. Make changes to `configuration.nix`
2. Test with `sudo nixos-rebuild dry-build` to check syntax
3. Apply with `sudo nixos-rebuild switch`
4. Commit changes to git after successful application

## Important Notes

- Never modify `hardware-configuration.nix` manually - it's auto-generated
- System packages are declared in `environment.systemPackages`
- User-specific packages should be added to the user's packages list
- Docker is enabled and auto-starts on boot
- The system uses systemd-boot as the bootloader

## Active Technologies
- Nix (NixOS configuration language) + tmux, mosh, openssh, wl-clipboard (001-remote-terminal-access)
- N/A (no persistent data beyond tmux sessions) (001-remote-terminal-access)
- Nix (NixOS 24.05, stateVersion "24.05") + nixpkgs (nixos-24.05 branch), home-manager (release-24.05 branch), 1Password GUI + CLI (002-nixos-homemanager-dotfiles)
- N/A (declarative configuration files only) (002-nixos-homemanager-dotfiles)

## Recent Changes
- 001-remote-terminal-access: Added Nix (NixOS configuration language) + tmux, mosh, openssh, wl-clipboard
