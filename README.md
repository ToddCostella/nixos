# NixOS Development Environment Configuration

A comprehensive NixOS system configuration for a development-focused desktop environment. Uses **Nix flakes** for reproducible builds and **Home Manager** for declarative dotfile management with **1Password** as the secrets backend.

## Quick Start

```bash
# Apply configuration changes (system + dotfiles, requires sudo)
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev

# Dry-run to check for syntax errors
sudo nixos-rebuild dry-build --flake ~/nixos-config#nixos-dev

# Rollback to previous generation
sudo nixos-rebuild rollback

# Update all dependency versions (nixpkgs + home-manager)
nix flake update ~/nixos-config
```

## Repository Structure

| File | Description |
|------|-------------|
| `flake.nix` | Flake inputs and outputs — entry point for all builds |
| `flake.lock` | Pinned dependency versions (committed to git) |
| `configuration.nix` | System config: packages, services, hardware, virtualization |
| `home.nix` | Home Manager: dotfiles, user packages, aliases, secrets |
| `hardware-configuration.nix` | Auto-generated hardware config (do not modify) |
| `remote-terminal.nix` | Mosh + SSH server hardening |
| `desktop-gnome.nix` | GNOME desktop environment (default) |
| `desktop-hyprland.nix` | Hyprland Wayland compositor (specialisation) |
| `desktop-cosmic.nix` | COSMIC desktop — System76 (specialisation) |
| `desktop-kde.nix` | KDE Plasma 6 (specialisation) |
| `desktop-icons.nix` | Custom desktop icons |
| `esp32-dev.nix` | ESP32 development environment |
| `photo-restoration.nix` | Photo editing and restoration tools |
| `playwright-dev.nix` | Playwright E2E testing dependencies |
| `start-dev.sh` | Launch tmux dev session for this repo |

## System Overview

### Desktop Environment

GNOME is the default. Three alternative DEs are baked into the build as [NixOS specialisations](https://nixos.wiki/wiki/NixOS_specialisations) — selectable at boot or switchable at runtime without a rebuild.

| Specialisation | DE | Boot menu label |
|---|---|---|
| *(default)* | GNOME | NixOS |
| `hyprland` | Hyprland | NixOS - Hyprland |
| `cosmic` | COSMIC | NixOS - COSMIC |
| `kde` | KDE Plasma 6 | NixOS - KDE-Plasma-6 |

**Switch at runtime (no reboot):**
```bash
sudo /run/current-system/specialisation/hyprland/bin/switch-to-configuration switch
sudo /run/current-system/specialisation/cosmic/bin/switch-to-configuration switch
sudo /run/current-system/specialisation/kde/bin/switch-to-configuration switch

# Back to default GNOME
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev
```

**Switch at boot:** Reboot and select from the systemd-boot menu.

- **GNOME** with GDM display manager (Wayland)
- **Extensions**: Forge (tiling), Workspace Indicator, Just Perfection
- **GNOME Tweaks** + **Papirus-Dark** icon theme
- **WezTerm** as default terminal

### Terminal & Shell
- **WezTerm** — GPU-accelerated terminal emulator
- **tmux** — persistent multiplexer (config in `home.nix`)
  - Prefix: `Alt-a`
  - Theme: Catppuccin Mocha
  - Plugins: catppuccin, sensible, yank, resurrect, continuum, tmux-sessionx
  - Window switch: `Alt+1`–`Alt+9` | Splits: `|`/`-` | Pane nav: `Alt+Arrow`
  - Session switcher: `Alt-a o` (tmux-sessionx with zoxide)
- **Mosh** — resilient remote connections (survives network interruptions)
- **Zsh** + Oh-My-Zsh (robbyrussell theme, plugins: git, docker, docker-compose, aws, vi-mode, fzf)
- **Atuin** — improved shell history | **Zoxide** — smart cd | **Yazi** — file manager

### Shell Aliases
| Alias | Command |
|-------|---------|
| `lg` | lazygit |
| `acv` | activate Python venv |
| `db/dbf/dbb` | cd to buoyancy-platform dirs |
| `dc` | docker compose watch backend |
| `nb` | npm run dev |
| `sx` | tmux-sessionx |
| `refresh-secrets` | regenerate `~/.secrets.env` from 1Password |

### Secrets Management
All sensitive values are sourced from **1Password** at runtime — nothing is committed in plaintext.

| Secret | Where used | How resolved |
|--------|-----------|--------------|
| AWS access keys | `~/.aws/credentials` | `op --cache inject` via `credential_process` |
| Anthropic API key | `~/.secrets.env` | `op inject` via `refresh-secrets` alias |
| SSH keys | SSH agent | 1Password SSH agent (`~/.1password/agent.sock`) |
| Git signing key | git commits | `op-ssh-sign` (automatic) |

```bash
# Regenerate ~/.secrets.env after rotating keys or first setup
refresh-secrets
```

### Development Tools

#### Core
| Tool | Description |
|------|-------------|
| Git | Managed by Home Manager — SSH signing via 1Password |
| Neovim | Text editor (config NOT managed — edit `~/.config/nvim/` freely) |
| Node.js 24 | With npm and Yarn |
| Python + uv | Python with modern package manager |
| Claude Code | AI coding assistant |
| AWS CLI v2 | With 4 profiles (default, toddcostella, buoyancy-dev, buoyancy-root) |
| AWS CDK | Infrastructure as code |
| GCC, Make, pkg-config | Build tools |

#### Containers & Cloud
| Tool | Description |
|------|-------------|
| Docker | Container runtime (auto-start on boot) |
| Docker Compose | Multi-container orchestration |
| Lazydocker | Terminal UI for Docker |

#### Database
| Tool | Description |
|------|-------------|
| DBeaver | Universal database tool |
| PostgreSQL client | `psql` |
| Rainfrog | Terminal DB manager with vim keybindings |

#### Version Control
| Tool | Description |
|------|-------------|
| Lazygit | Terminal UI for Git |
| GitHub CLI (`gh`) | GitHub operations from terminal |
| Beyond Compare | Professional diff/merge |

### Virtualization

#### QEMU/KVM
- **GNOME Boxes** — simple VM management
- **libvirtd** — full virtualization stack
- **OVMF/UEFI** — Secure Boot support
- **swtpm** — TPM 2.0 emulation for Windows 11
- **virtio-win** — Windows virtio drivers
- **Nested virtualization** + **IOMMU** configured
- **Samba** — shared folders between host and VM

### CLI Utilities

| Tool | Replaces | Description |
|------|----------|-------------|
| ripgrep | grep | Fast recursive search |
| fd | find | User-friendly file finder |
| bat | cat | Syntax highlighting |
| fzf | — | Fuzzy finder |
| zoxide | cd | Smart directory jumping |
| jq / yq-go | — | JSON/YAML processors |
| httpie | curl | Modern HTTP client |

### Network Tools
- **Diagnostics**: dig, traceroute, mtr, nmap, netcat, socat, tcpdump, wireshark, iperf3, iftop, nethogs
- **Proxy/intercept**: mitmproxy (`mitm-localhost` helper script)
- **VPN**: OpenVPN, wgnord (NordVPN WireGuard)
- **Open ports**: 3000 (Vite dev server), 8080 (WebSocket / mitmproxy)

### Screenshot Tools
Custom scripts save to `~/dev/buoyancy-platform/tmp/current-screenshot.png` for Claude Code integration:

| Command | Description |
|---------|-------------|
| `screenshot-area` | Area selection with Satty annotation |
| `screenshot-full` | Full screen with Satty annotation |
| `screenshot-window` | Active window with Satty annotation |
| `screenshot-quick` | Quick area capture, no annotation |

### Microcontroller Development
- **ESP32**: esptool, espflash, PlatformIO, screen, picocom, minicom (see `esp32-dev.nix`)
- **Arduino IDE** + **Mu Editor**
- **Bazecor** — Dygma keyboard configurator

### Photo & Image Editing (see `photo-restoration.nix`)
- **GUI**: Pinta, GIMP, Darktable, RawTherapee, Upscayl, DigiKam, Hugin
- **CLI**: ImageMagick, G'MIC, ExifTool
- **Color management**: DisplayCAL, ArgyllCMS

### Productivity & Communication
- **Obsidian**, **LibreOffice**, **Apostrophe** (markdown), **Figma**
- **1Password** (GUI + CLI integration enabled)
- **Dropbox**, **Pika Backup**
- **Slack**, **Signal Desktop**, **Zoom**

### Web Browsers
- **Firefox**, **Google Chrome**, **Zen Browser** (privacy-focused Firefox fork)

### Fonts
- **Nerd Fonts**: Fira Code, JetBrains Mono, Hack, Sauce Code Pro
- **System**: Noto CJK Sans, Noto Emoji, Liberation TTF, Fira Code

## System Services

| Service | Description |
|---------|-------------|
| NetworkManager | Network (with OpenVPN plugin) |
| OpenSSH | SSH server (key-only, no root login) |
| Mosh | Resilient remote terminal (UDP 60000-61000) |
| CUPS + Avahi | Printing + mDNS (`nixos-dev.local`) |
| Docker | Container runtime (auto-start) |
| libvirtd | Virtualization daemon |
| Bluetooth + Blueman | Bluetooth support |
| PipeWire | Audio (ALSA + PulseAudio compat + JACK) |
| GNOME Keyring | Credential storage |
| nix-ld | Dynamic linking support |
| 1Password | SSH agent + CLI integration |

## Remote Terminal Access

Connect from iOS or any device via SSH or Mosh:

```bash
# SSH
ssh todd@nixos-dev.local

# Mosh (resilient — survives WiFi drops and sleep/wake)
mosh todd@nixos-dev.local

# Attach to persistent tmux session
tmux new-session -As main
```

Add your public key to `~/.ssh/authorized_keys`. Password auth is disabled.

## Development Session Launcher

`start-dev.sh` creates a tmux session with 3 windows for working on this repo:

```bash
bash ~/nixos-config/start-dev.sh
```

| Window | Contents |
|--------|----------|
| 1 | Claude AI (`claude`) |
| 2 | Terminal |
| 3 | Yazi file manager |

## System Information

| Setting | Value |
|---------|-------|
| Hostname | nixos-dev |
| Timezone | America/Vancouver |
| Locale | en_US.UTF-8 |
| Bootloader | systemd-boot |
| NixOS channel | nixos-unstable (via flake) |
| Home Manager | master (via flake) |

## Troubleshooting

### Numbered tmux sessions accumulating (11, 13, 14, 16…)

These are created by **tmux-resurrect** during restore when it can't match a saved session to a running named session. They get saved by continuum and recreated on every restore, perpetuating the cycle.

**Fix:** kill them all, then let continuum save a clean snapshot:

```bash
# Kill all purely numeric sessions
tmux list-sessions -F '#{session_name}' | grep -E '^[0-9]+$' | xargs -I{} tmux kill-session -t {}

# Force continuum to save the clean state immediately
~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh
```

Make sure your named sessions (nixos, dev-buoyancy, gloom) are running before the save fires, otherwise they'll be missing from the snapshot and the cycle may repeat.

## Important Notes

- **Never modify** `hardware-configuration.nix` — auto-generated
- **`flake.lock` must be committed** — it pins exact dependency versions
- **System packages** → `environment.systemPackages` in `configuration.nix`
- **User packages + dotfiles** → `home.nix`
- **SSH server** config is in `remote-terminal.nix`; **SSH client** config is in `home.nix`
- **`~/.secrets.env` is not committed** — run `refresh-secrets` after a fresh clone
- **Neovim config** (`~/.config/nvim/`) is intentionally unmanaged — edit freely without rebuilding
- Forge GNOME extension requires GNOME 48 or earlier
- Weekly automatic garbage collection of Nix store generations older than 30 days
