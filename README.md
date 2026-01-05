# NixOS Development Environment Configuration

A comprehensive NixOS system configuration for a development-focused desktop environment with support for web development, microcontroller programming, photo editing, virtualization, and DevOps workflows.

## Quick Start

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

### Channel Management
```bash
# Update to latest packages
sudo nix-channel --update
sudo nixos-rebuild switch

# Rollback channel (if update causes issues)
sudo nix-env --profile /nix/var/nix/profiles/per-user/root/channels --rollback
sudo nixos-rebuild switch --rollback
```

## Repository Structure

| File | Description |
|------|-------------|
| `configuration.nix` | Main NixOS configuration file |
| `hardware-configuration.nix` | Auto-generated hardware config (do not modify) |
| `desktop-gnome.nix` | GNOME desktop environment configuration |
| `desktop-icons.nix` | Custom desktop icons for Nix applications |
| `esp32-dev.nix` | ESP32 development environment |
| `photo-restoration.nix` | Photo editing and restoration tools |
| `playwright-dev.nix` | Playwright E2E testing dependencies |
| `CLAUDE.md` | AI assistant guidance for repository maintenance |
| `PLAYWRIGHT-SETUP.md` | Playwright setup and usage guide |

Note: `desktop-kde.nix`, `desktop-cinnamon.nix`, and `desktop-multi-de-compat.nix` exist for multi-DE support but are currently disabled. Only GNOME is active.

## System Overview

### Desktop Environment
- **GNOME** desktop with GDM display manager
- **Extensions**:
  - Forge (tiling window manager) - Note: Requires GNOME 48 or earlier
  - Workspace Indicator
  - Just Perfection
- **GNOME Tweaks** for customization
- **Papirus-Dark** icon theme
- Wayland native with XDG portals

### Development Tools

#### Core Development
| Tool | Description |
|------|-------------|
| Git | Pre-configured with user details |
| Neovim | Text editor (default EDITOR) |
| GCC, Make, pkg-config | Build tools |
| Node.js 24 | With npm and Yarn |
| Python + uv | Python with modern package manager |
| Claude Code | AI coding assistant |
| AWS CDK | Infrastructure as code |
| Playwright | E2E testing (see `playwright-dev.nix`) |

#### Containers & Cloud
| Tool | Description |
|------|-------------|
| Docker | Container runtime with auto-start |
| Docker Compose | Multi-container orchestration |
| Lazydocker | Terminal UI for Docker |
| AWS CLI v2 | Amazon Web Services CLI |

#### Database & Version Control
| Tool | Description |
|------|-------------|
| DBeaver | Universal database tool |
| Lazygit | Terminal UI for Git |
| Beyond Compare | Professional diff/merge tool |

### Virtualization

#### QEMU/KVM (Windows 11 Support)
- **GNOME Boxes** - Simple VM management
- **libvirtd** - Full virtualization stack
- **OVMF/UEFI** - Secure Boot support
- **swtpm** - TPM 2.0 emulation for Windows 11
- **virtio-win** - Windows virtio drivers
- **Samba** - Shared folders between host and VM
- **Nested virtualization** enabled
- **IOMMU** configured for device passthrough

### Terminal & Shell
- **Wezterm** - GPU-accelerated terminal emulator (default)
- **Zsh** with Oh-My-Zsh
  - Plugins: git, docker, docker-compose, aws, vi-mode, fzf
  - Theme: robbyrussell
- **Direnv** - Environment variable management with nix-direnv
- **Atuin** - Improved shell history
- **Zoxide** - Smarter cd command
- **Yazi** - Terminal file manager

### CLI Utilities

#### Modern Replacements
| Tool | Replaces | Description |
|------|----------|-------------|
| ripgrep | grep | Fast recursive search |
| fd | find | User-friendly file finder |
| bat | cat | Syntax highlighting |
| fzf | - | Fuzzy finder |
| zoxide | cd | Smart directory jumping |

#### Data Processing
- **jq** - JSON processor
- **yq-go** - YAML processor
- **httpie** - Modern HTTP client
- **tree** - Directory listing

### Network Tools

#### Diagnostics
| Tool | Description |
|------|-------------|
| dig, nslookup, drill | DNS lookups |
| traceroute, mtr | Network path analysis |
| nmap | Network scanning |
| netcat, socat | Network utilities |
| tcpdump, wireshark | Packet analysis |
| iperf3 | Bandwidth testing |
| iftop, nethogs | Bandwidth monitoring |

#### VPN
- **OpenVPN** - For NordVPN manual configuration
- **wgnord** - Unofficial NordVPN WireGuard client

### Microcontroller Development

#### ESP32
- **esptool, espflash** - ESP-IDF tools
- **PlatformIO** - Professional embedded IDE
- **screen, picocom, minicom** - Serial monitors
- **USB permissions** - Pre-configured for ESP32 devices

#### Other
- **Arduino IDE** - Arduino development
- **Mu Editor** - Simple Python editor for microcontrollers
- **Bazecor** - Dygma keyboard configurator

### Photo & Image Editing

#### GUI Applications
| Tool | Description |
|------|-------------|
| Pinta | Simple image editor |
| GIMP | Advanced editor with plugins |
| Darktable | Professional photo workflow |
| RawTherapee | RAW photo processor |
| Upscayl | AI-powered image upscaler |
| DigiKam | Photo management |
| Hugin | Panorama stitcher |

#### Command-Line
- **ImageMagick** - Image processing suite
- **G'MIC** - Image processing framework
- **ExifTool** - Metadata tool

#### Color Management
- **DisplayCAL** - Display calibration
- **ArgyllCMS** - Color management system

### Productivity & Communication

#### Productivity
- **Obsidian** - Knowledge management
- **LibreOffice** - Office suite
- **Apostrophe** - Markdown editor
- **1Password** - Password manager
- **Dropbox** - Cloud storage
- **Pika Backup** - Backup software

#### Communication
- **Slack** - Team collaboration
- **Signal Desktop** - Secure messaging
- **Zoom** - Video conferencing

### Web Browsers
- **Firefox** - Open-source browser
- **Google Chrome** - Chromium-based browser
- **Zen Browser** - Privacy-focused Firefox fork

### Screenshot Tools
Custom scripts save to `~/dev/buoyancy-platform/tmp/` for easy Claude Code integration:

| Command | Description |
|---------|-------------|
| `screenshot-area` | Capture selected area (saves + clipboard) |
| `screenshot-full` | Capture full screen |
| `screenshot-window` | Capture active window |
| `screenshot-latest` | Get path of most recent screenshot |

Screenshots are saved to a static filename (`current-screenshot.png`) for easy reference in Claude Code.

### Fonts
- **Nerd Fonts**: Fira Code, JetBrains Mono, Hack, Sauce Code Pro
- **System**: Noto CJK Sans, Noto Emoji, Liberation TTF, Fira Code

## System Services

| Service | Description |
|---------|-------------|
| NetworkManager | Network configuration (with OpenVPN plugin) |
| OpenSSH | SSH server |
| CUPS + Avahi | Printing with network discovery |
| Docker | Container runtime (auto-start) |
| libvirtd | Virtualization daemon |
| Bluetooth + Blueman | Bluetooth support |
| PipeWire | Modern audio system |
| GNOME Keyring | Credential storage |
| nix-ld | Dynamic linking support |

## User Configuration

- **Primary User**: todd
- **Shell**: Zsh with Oh-My-Zsh
- **Groups**: networkmanager, wheel, docker, dialout, libvirtd
- **Git**:
  - Name: Todd Costella
  - Email: ToddCostella@gmail.com
  - Default branch: main

## System Information

| Setting | Value |
|---------|-------|
| Hostname | nixos-dev |
| Timezone | America/Vancouver |
| Locale | en_US.UTF-8 |
| Bootloader | systemd-boot |
| State Version | 24.05 |

## Important Notes

- **Never modify** `hardware-configuration.nix` manually
- **Forge extension** requires GNOME 48 or earlier (GNOME 49+ not yet supported)
- Docker starts automatically on boot
- Performance CPU governor is enabled for VM workloads
- Flakes and nix-command experimental features are enabled
- Weekly automatic garbage collection of old generations