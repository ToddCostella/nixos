# NixOS Development Environment Configuration

A comprehensive NixOS system configuration for a development-focused desktop environment with support for web development, microcontroller programming, photo editing, and DevOps workflows.

## 🚀 Quick Start

### Apply Configuration Changes
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
```bash
# Dry-run to check for syntax errors
sudo nixos-rebuild dry-build
```

## 📁 Repository Structure

- `configuration.nix` - Main NixOS configuration file containing system settings, user accounts, packages, and services
- `hardware-configuration.nix` - Auto-generated hardware-specific configuration (do not modify manually)
- `esp32-dev.nix` - ESP32 development environment configuration
- `photo-restoration.nix` - Photo editing and restoration tools configuration
- `CLAUDE.md` - AI assistant guidance for repository maintenance

## 💻 System Overview

### Desktop Environment
- **GNOME** desktop with GDM display manager
- **Extensions**: Forge (window tiling), Workspace Indicator
- **GNOME Tweaks** for customization
- Wayland/X11 support with XDG portals

### Development Tools

#### Core Development
- **Git** - Pre-configured with user details
- **Neovim** - Text editor
- **Build Tools** - GCC, Make, pkg-config
- **Node.js 24** - With npm and Yarn package managers
- **Python** - With uv package manager
- **Claude Code** - AI coding assistant

#### Containers & Cloud
- **Docker** - With Docker Compose and auto-start on boot
- **AWS CLI v2** - Amazon Web Services command-line interface
- **Lazydocker** - Terminal UI for Docker

#### Database Management
- **DBeaver** - Universal database tool

#### Version Control
- **Lazygit** - Terminal UI for Git
- **Beyond Compare** - Professional diff/merge tool

### 🖥️ Terminal & Shell
- **Wezterm** - GPU-accelerated terminal emulator
- **Zsh** with Oh-My-Zsh
  - Plugins: git, docker, docker-compose, aws, vi-mode, fzf
  - Theme: robbyrussell
- **Direnv** - Environment variable management with nix-direnv

### 🛠️ Development Utilities

#### Modern CLI Tools
- **ripgrep** - Fast recursive grep
- **fd** - User-friendly alternative to find
- **bat** - Cat clone with syntax highlighting
- **fzf** - Fuzzy finder
- **atuin** - Improved shell history

#### Data Processing
- **tree** - Directory listing
- **jq** - JSON processor
- **yq-go** - YAML processor
- **httpie** - Modern HTTP client

### 🔧 Microcontroller Development

#### ESP32 Development
- **ESP-IDF Tools** - esptool, espflash
- **PlatformIO** - Professional IDE for embedded development
- **Serial Monitors** - screen, picocom, minicom
- **USB Utilities** - lsusb, usb-modeswitch

#### Other Microcontroller Tools
- **Arduino IDE** - Arduino development environment
- **Mu Editor** - Simple Python editor for microcontrollers
- **Bazecor** - Dygma keyboard configurator

### 📸 Photo & Image Editing

#### GUI Applications
- **Pinta** - Simple image editor
- **GIMP** - Advanced image editor with plugins
- **Darktable** - Professional photo workflow
- **RawTherapee** - RAW photo processor
- **Upscayl** - AI-powered image upscaler
- **DigiKam** - Photo management with basic editing
- **Hugin** - Panorama photo stitcher

#### Command-Line Tools
- **ImageMagick** - Image processing suite
- **G'MIC** - Framework for image processing
- **ExifTool** - Read/write image metadata

#### Color Management
- **DisplayCAL** - Display calibration and profiling
- **ArgyllCMS** - Color management system

### 🎯 Productivity Applications
- **Obsidian** - Knowledge management and note-taking
- **LibreOffice** - Complete office suite
- **1Password** - Password manager
- **Dropbox** - Cloud storage synchronization

### 💬 Communication
- **Slack** - Team collaboration
- **Signal Desktop** - Secure messaging
- **Zoom** - Video conferencing

### 🌐 Web Browsers
- **Firefox** - Open-source browser
- **Google Chrome** - Chromium-based browser

### 🎨 Media & System Tools
- **feh** - Lightweight image viewer
- **playerctl** - Media player control
- **brightnessctl** - Screen brightness control
- **GNOME Screenshot** - With custom screenshot scripts
  - `screenshot-area` - Capture selected area
  - `screenshot-full` - Capture full screen
  - `screenshot-window` - Capture active window

### 🔤 Fonts
- **Nerd Fonts Collection**:
  - Fira Code
  - JetBrains Mono
  - Hack
  - Sauce Code Pro
- **System Fonts**:
  - Noto CJK Sans
  - Noto Emoji
  - Liberation TTF

## 🔧 System Services

### Enabled Services
- **NetworkManager** - Network configuration
- **OpenSSH** - SSH server
- **CUPS** - Printing support
- **Docker** - Container runtime with auto-start
- **Bluetooth** - With Blueman manager
- **PipeWire** - Modern audio system
- **GNOME Keyring** - Credential storage
- **Polkit** - Authentication agent
- **nix-ld** - Dynamic linking support

### System Features
- **Automatic Nix garbage collection** - Weekly cleanup of old generations
- **Flakes** - Experimental Nix features enabled
- **USB permissions** - Configured for ESP32 and microcontroller development

## 👤 User Configuration

- **Primary User**: todd
- **Shell**: Zsh with Oh-My-Zsh
- **Groups**: networkmanager, wheel, docker, dialout
- **Git Configuration**:
  - Name: Todd Costella
  - Email: ToddCostella@gmail.com
  - Default branch: main

## 🔄 Development Workflow

1. Make changes to configuration files
2. Test with `sudo nixos-rebuild dry-build`
3. Apply with `sudo nixos-rebuild switch`
4. Commit changes to git after successful application

## ⚠️ Important Notes

- **Never modify** `hardware-configuration.nix` manually - it's auto-generated
- System packages are declared in `environment.systemPackages`
- User-specific packages should be added to the user's packages list
- Docker is configured to start automatically on boot
- The system uses systemd-boot as the bootloader

## 🌍 System Information

- **Hostname**: nixos-dev
- **Timezone**: America/Vancouver
- **Locale**: en_US.UTF-8
- **NixOS Version**: 24.05

## 📝 License

This configuration is provided as-is for personal use and reference.

## 🤝 Contributing

Feel free to fork this configuration and adapt it to your needs. If you find useful improvements, issues can be reported through GitHub.