# NixOS Development Environment Configuration

A multi-host NixOS configuration for a development-focused desktop and headless home server. Uses **Nix flakes** for reproducible builds and **Home Manager** for declarative dotfile management with **1Password** as the secrets backend.

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

```
nixos-config/
├── flake.nix                        # Two hosts, split home modules
├── flake.lock                       # Pinned dependency versions
├── hosts/
│   ├── nixos-dev/
│   │   ├── configuration.nix        # Laptop-specific config + specialisations
│   │   └── hardware-configuration.nix
│   └── home-server/
│       ├── configuration.nix        # Headless server config
│       └── hardware-configuration.nix
├── modules/
│   ├── common.nix                   # Shared: nix settings, locale, avahi, core CLI
│   ├── remote-terminal.nix          # Mosh + SSH hardening
│   ├── desktop-gnome.nix            # GNOME desktop environment
│   ├── desktop-icons.nix            # Custom desktop application icons
│   ├── nordvpn.nix                  # NordVPN WireGuard (wgnord)
│   ├── playwright-dev.nix           # Playwright E2E testing dependencies
│   ├── esp32-dev.nix                # ESP32 microcontroller development tools
│   ├── photo-restoration.nix        # Photo editing and restoration applications
│   ├── desktop-cinnamon.nix         # Cinnamon desktop
│   └── desktop-cosmic.nix           # COSMIC desktop (unused, in specialisation)
│   #  (hyprland + KDE specialisations are defined inline in nixos-dev/configuration.nix)
├── home/
│   ├── todd-base.nix                # Headless-safe: git, zsh, herdr, SSH, AWS, CLI tools
│   ├── todd-desktop.nix             # GUI apps + Maestral/Proton Bridge (nixos-dev)
│   ├── mail.nix                     # Email stack: mbsync/msmtp/notmuch/aerc/Thunderbird
│   └── *.py                         # Mail helpers (archive_old_inbox, analyze_senders, …)
├── scripts/
│   ├── start-server.sh              # SSH into home-server (herdr workspace)
│   └── home-server-install.sh       # Home server bootstrap script
├── start-dev.sh                     # Launch herdr dev workspace for this repo
└── DROPBOX-MAESTRAL.md              # Dropbox-via-Maestral setup + rationale
```

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
- **Extensions**: Forge (tiling), Workspace Indicator, Just Perfection, Tactile, Switcher, Sound Output Device Chooser
- **GNOME Tweaks** + **WezTerm** as default terminal

### Terminal & Shell
- **WezTerm** — GPU-accelerated terminal emulator
- **herdr** — terminal workspace manager for AI coding agents; replaced tmux as the multiplexer (nixos-dev; via flake overlay, config in `home/todd-base.nix`)
  - Prefix: `alt+a` | Tabs: `Alt+1`–`Alt+9` (new: `prefix+c`) | Pane focus: `Alt+Arrow` | Splits: `prefix+\` / `prefix+-`
  - Theme follows the host terminal's ANSI palette; mouse capture + copy-on-select on; notifications shown as in-app toasts, sound disabled
  - `Ctrl+h/j/k/l` navigates seamlessly across Neovim splits and herdr panes (vim-herdr-navigation)
- **Mosh** — resilient remote connections (survives network interruptions)
- **Zsh** + Oh-My-Zsh (robbyrussell theme, plugins: git, docker, docker-compose, aws, vi-mode, fzf)
- **Atuin** — improved shell history | **Zoxide** — smart cd | **Yazi** / **superfile** — file managers

### Shell Aliases
| Alias | Command |
|-------|---------|
| `lg` | lazygit |
| `acv` | activate Python venv |
| `db/dbf/dbb` | cd to buoyancy-platform dirs |
| `dc` | docker compose watch backend |
| `nb` | npm run dev |
| `hs` | SSH into home-server (start-server.sh) |
| `mail` | launch mail session (aerc + shell + yazi + Claude) |
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
| AWS CLI v2 | 5 profiles: default, toddcostella, buoyancy-dev, buoyancy-root, buoyancy-prod (assumes role via buoyancy-root) |
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
| btop | htop | Resource monitor |

### Network Tools
- **Diagnostics**: dig, traceroute, mtr, nmap, netcat, socat, tcpdump, wireshark, iperf3, iftop, nethogs
- **Proxy/intercept**: mitmproxy (`mitm-localhost` helper script)
- **VPN**: OpenVPN, wgnord (NordVPN WireGuard)
- **Open ports**: 3000 (Vite dev server), 8080 (WebSocket / mitmproxy)

### Screenshot Tools
Use GNOME's built-in screenshot UI (`Print`). It captures via Mutter and copies
to the clipboard for pasting into Claude Code. The old custom `screenshot-*`
scripts were removed — they wrapped `gnome-screenshot`, which is broken on GNOME
Wayland (empty X11 fallback). See CLAUDE.md → Screenshot Tools for the full
rationale.

### Microcontroller Development
- **ESP32**: esptool, espflash, PlatformIO, screen, picocom, minicom (see `esp32-dev.nix`)
- **Arduino IDE** + **Mu Editor**
- **Bazecor** — Dygma keyboard configurator

### Photo & Image Editing (see `photo-restoration.nix`)
- **GUI**: Pinta, GIMP, Darktable, RawTherapee, Upscayl, DigiKam, Hugin
- **CLI**: ImageMagick, G'MIC, ExifTool
- **Color management**: DisplayCAL, ArgyllCMS

### Productivity & Communication
- **Obsidian**, **LibreOffice**, **Apostrophe** (markdown), **Figma**, **Hugo** (static site generator)
- **1Password** (GUI + CLI integration enabled)
- **Maestral** (Dropbox sync — see [DROPBOX-MAESTRAL.md](DROPBOX-MAESTRAL.md)), **Pika Backup**
- **Slack**, **Signal Desktop**, **Zoom**

#### Email (Proton, via `home/mail.nix`)
Proton mail synced locally through **Proton Mail Bridge** (systemd service exposing
IMAP/SMTP on `127.0.0.1`), with a decoupled Maildir stack:
- **mbsync** (isync) — pulls Bridge IMAP → local Maildir on a 5-min timer
- **notmuch** — indexes the Maildir for instant local search
- **msmtp** — sends via the Bridge
- **aerc** (terminal, notmuch backend) and **Thunderbird** (GUI) as clients

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
| fwupd | Firmware update daemon |
| Maestral | Dropbox sync (`~/Dropbox`) — see [DROPBOX-MAESTRAL.md](DROPBOX-MAESTRAL.md) |
| Proton Mail Bridge | Local IMAP/SMTP for Proton mail (`127.0.0.1:1143`/`1025`) |
| mbsync | Proton → Maildir sync (systemd user timer, every 5 min) |

## Remote Terminal Access

Connect from iOS or any device via SSH or Mosh:

```bash
# SSH
ssh todd@nixos-dev.local

# Mosh (resilient — survives WiFi drops and sleep/wake)
mosh todd@nixos-dev.local

# Attach to the persistent herdr session
herdr

# Connect to home-server
hs
```

Add your public key to `~/.ssh/authorized_keys`. Password auth is disabled.

## Development Session Launcher

`start-dev.sh` creates a **Herdr** workspace (`🛠 nixos`) with 3 tabs for working
on this repo:

```bash
bash ~/nixos-config/start-dev.sh
```

| Tab | Contents |
|-----|----------|
| Claude AI | `nixos-claude` — a first-class Herdr-managed agent (lifecycle tracked) |
| Terminal | Bare shell at the repo root |
| Yazi | File manager (`y`) |

It is idempotent: re-running reuses the workspace and only creates missing tabs
(no kill-and-rebuild).

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

### Dropbox not syncing

Dropbox runs via **Maestral**, not the official client (which couldn't complete
syncing in the bwrap sandbox on GNOME/Wayland). Check `maestral status`; for
setup, the why, and gotchas see [DROPBOX-MAESTRAL.md](DROPBOX-MAESTRAL.md).

## Recent Changes

Generation history (use `nix run nixpkgs#nvd -- diff /nix/var/nix/profiles/system-{N}-link /nix/var/nix/profiles/system-{N+1}-link` to inspect any pair):

| Date | Generation | What changed |
|------|-----------|--------------|
| 2026-07-29 | — | Added `herdr` terminal agent multiplexer (nixos-dev, via flake overlay) with tmux-style keybindings, terminal theme, in-app toast notifications (sound off), and zsh completions; added `superfile` TUI file manager alongside Yazi |
| 2026-07-25 | — | Updated flake inputs (~2mo); removed `sound-output-device-chooser` (dropped from nixpkgs — use GNOME quick-settings sound picker); migrated `programs.ssh.matchBlocks` → `settings` and `texlive.combined.scheme-medium` → `texliveMedium` |
| 2026-03-23 | 134 → 136 | Added `sound-output-device-chooser` GNOME extension and enabled it declaratively via dconf |
| 2026-03-16 | 132 → 133 | Replaced `htop` with `btop`; added iPad Termius SSH key to `authorized_keys` |

## Important Notes

- **Never modify** `hardware-configuration.nix` — auto-generated
- **`flake.lock` must be committed** — it pins exact dependency versions
- **System packages** → `environment.systemPackages` in `hosts/<name>/configuration.nix`
- **CLI user packages + dotfiles** → `home/todd-base.nix`; GUI packages → `home/todd-desktop.nix`
- **SSH server** config is in `modules/remote-terminal.nix`; **SSH client** config is in `home/todd-base.nix`
- **`~/.secrets.env` is not committed** — run `refresh-secrets` after a fresh clone
- **Neovim config** (`~/.config/nvim/`) is intentionally unmanaged — edit freely without rebuilding
- Weekly automatic garbage collection of Nix store generations older than 30 days
