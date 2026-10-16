# NixOS Development Environment Configuration

A multi-host NixOS configuration for a development-focused desktop, a persistent development VM, and a headless home server. Uses **Nix flakes** for reproducible builds and **Home Manager** for declarative dotfile management with **1Password** as the secrets backend.

## Quick Start

```bash
# Apply configuration changes (system + dotfiles, requires sudo)
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev

# Dry-run to check for syntax errors
sudo nixos-rebuild dry-build --flake ~/nixos-config#nixos-dev

# Rollback to previous generation
sudo nixos-rebuild rollback

# Update all dependency versions (nixpkgs, home-manager, herdr, catppuccin-cosmic)
nix flake update ~/nixos-config

# Other flake targets
sudo nixos-rebuild switch --flake ~/nixos-config#vm-guest   # persistent libvirt VM
nixos-rebuild build-vm --flake ~/nixos-config#vm-test       # throwaway test VM
```

## Repository Structure

```
nixos-config/
├── flake.nix                        # 4 targets: nixos-dev, vm-guest, vm-test, home-server
├── flake.lock                       # Pinned dependency versions
├── hosts/
│   ├── nixos-dev/
│   │   ├── configuration.nix        # Physical-machine-only (boot, hugepages, EPP, virt)
│   │   ├── desktop-tools.nix        # SHARED desktop + tools layer; also imported by
│   │   │                            #   vm-guest. Holds the DE, dev tooling, 1Password,
│   │   │                            #   fonts, package set, scripts, DE specialisations
│   │   └── hardware-configuration.nix
│   ├── vm-guest/                    # Persistent libvirt VM (see docs/vm-guest-install.md)
│   └── home-server/                 # Headless server config
├── modules/
│   ├── common.nix                   # Shared: nix settings, locale, avahi, core CLI
│   ├── remote-terminal.nix          # Mosh + SSH hardening
│   ├── desktop-gnome.nix            # GNOME — the FALLBACK desktop, and the only DE
│   │                                #   module left; imported by the gnome
│   │                                #   specialisation in desktop-tools.nix
│   ├── desktop-icons.nix            # Custom desktop application icons
│   ├── nordvpn.nix                  # NordVPN WireGuard (wgnord)
│   ├── playwright-dev.nix           # Playwright E2E testing dependencies
│   ├── esp32-dev.nix                # ESP32 microcontroller development tools
│   └── photo-restoration.nix        # Photo editing and restoration applications
├── home/
│   ├── todd-base.nix                # Headless-safe: git, zsh, herdr, SSH, AWS, CLI tools
│   ├── todd-desktop.nix             # GUI apps + Maestral/Proton Bridge (nixos-dev, vm-guest)
│   ├── mail.nix                     # Email stack: mbsync/msmtp/notmuch/aerc/Thunderbird
│   └── *.py                         # Mail helpers (archive_old_inbox, analyze_senders, …)
├── scripts/
│   ├── start-server.sh              # SSH into home-server (herdr workspace)
│   ├── start-mail.sh                # Launch the mail session
│   ├── home-server-install.sh       # Home server bootstrap
│   └── vm-guest-{install,provision}.sh
├── docs/                            # vm-guest-install.md, new-drives-plan.md, rack-wishlist.md
├── start-dev.sh                     # Launch herdr dev workspace for this repo
└── DROPBOX-MAESTRAL.md              # Dropbox-via-Maestral setup + rationale
```

## System Overview

### Desktop Environment

**COSMIC is the default desktop**, themed with Catppuccin Mocha. **GNOME is the
one fallback**, available as a [NixOS specialisation](https://nixos.wiki/wiki/NixOS_specialisations)
— selectable at boot or switchable at runtime without a rebuild.

Reorganised 2026-10-16: COSMIC was previously a specialisation on top of a GNOME
base, and KDE Plasma 6 + Hyprland were also specialisations. Both were removed;
COSMIC became the base and GNOME the fallback.

| System | DE | Boot menu label |
|---|---|---|
| *(base)* | COSMIC | NixOS |
| `gnome` specialisation | GNOME | NixOS - GNOME |

COSMIC is configured inline in `hosts/nixos-dev/desktop-tools.nix`; the `gnome`
specialisation in the same file imports `modules/desktop-gnome.nix` and forces
COSMIC off. The five unused standalone DE modules (cosmic, hyprland, kde,
cinnamon, multi-de-compat) were **deleted** on 2026-10-16 — nothing imported
them, so `desktop-gnome.nix` is the only DE module left.

PR #6 (Omarchy-flavoured Hyprland) was closed as abandoned. Its
`origin/hyprland-omarchy` branch still holds that work if Hyprland is revisited.

**Switch at runtime (no reboot):**
```bash
# To the GNOME fallback
sudo /run/current-system/specialisation/gnome/bin/switch-to-configuration switch

# Back to COSMIC (the base)
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev
```

**Switch at boot:** Reboot and select from the systemd-boot menu.

A `nixos-rebuild switch` builds the base system and its specialisation, and the
boot menu gains the `NixOS - GNOME` entry for that generation — so the usual
rebuild → reboot flow picks up config changes.

The GNOME specialisation tags the system name, so when booted it shows in
`/run/current-system` (e.g. `…-nixos-dev-GNOME-26.11…`); the base COSMIC system
carries no tag. When booted into a specialisation that path is the
*specialisation's*, while `/nix/var/nix/profiles/system` is the generation's
*base* — they differ by design, and both come from the same generation.

- **COSMIC** (Wayland) with GDM as the display manager
- **`gnome-keyring` is enabled even though GNOME is not the base** — despite the
  name it is the de-facto org.freedesktop.secrets provider and COSMIC ships no
  replacement, without which 1Password cannot store its 2FA token
- **GNOME fallback extensions**: Forge (tiling), Workspace Indicator, Just
  Perfection, Tactile, Switcher

### Theming
**Catppuccin Mocha** (accent Blue, `#89b4fa`) across COSMIC and Ghostty. Ghostty's
Mocha `palette = 4` is the same blue as the COSMIC accent, and herdr inherits the
palette via `theme = terminal`.

- **Ghostty** — declarative: `theme = Catppuccin Mocha` in `home/todd-desktop.nix`
  (Ghostty ships all four flavors itself)
- **COSMIC** — not declarative; the `catppuccin-cosmic` flake input is pinned and
  surfaced at `~/.local/share/catppuccin-cosmic`, then imported once via
  Settings → Desktop → Appearance → Import (and COSMIC Term → View → Color schemes)
- **catppuccin-whiskers** — renders the `.tera` templates for accent/roundness/gap
  combinations outside the 56 prebuilt RONs

Caveat on cosmic-comp 1.9.0: the themes target the v1 schema while 1.9.0 writes v2.
Colors migrate; transparency does not (v1's `is_frosted` became six separate toggles
plus an `alpha_map`), so set frosted/blur by hand after importing.

### Terminal & Shell
- **Ghostty** — default terminal since 2026-10-08; replaced WezTerm because
  terminal-browser needs the full kitty graphics protocol, which WezTerm only
  partially implements. Config is declarative in `home/todd-desktop.nix`
- **WezTerm** — still installed, but no longer the default anywhere. `TERMINAL = "wezterm"` now only comes from `modules/desktop-gnome.nix`, i.e. the GNOME fallback (the KDE specialisation that also set it was removed 2026-10-16)
- **herdr** 0.9.4 — terminal workspace manager for AI coding agents; replaced tmux as the multiplexer (nixos-dev; via flake overlay, config in `home/todd-base.nix`)
  - Prefix: `alt+a` | Tabs: `Alt+1`–`Alt+9` (new: `prefix+c`) | Pane focus: `Alt+Arrow` | Splits: `prefix+\` / `prefix+-`
  - Workspaces: `prefix+w` + number by index; `prefix+g` opens the name-searchable navigator
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
- **Open ports**: nixos-dev 3000 (Vite dev server), 8080 (WebSocket / mitmproxy); home-server 53/80 (DNS/HTTP)

### Screenshot Tools
Use GNOME's built-in screenshot UI (`Print`). It captures via Mutter and copies
to the clipboard for pasting into Claude Code. The old custom `screenshot-*`
scripts were removed — they wrapped `gnome-screenshot`, which is broken on GNOME
Wayland (empty X11 fallback). See CLAUDE.md → Screenshot Tools for the full
rationale.

Under the COSMIC specialisation this does not apply — COSMIC ships
`cosmic-screenshot`, bound to `Print` via its `Screenshot` system action.

### Microcontroller Development
- **ESP32**: esptool, espflash, PlatformIO, screen, picocom, minicom (see `esp32-dev.nix`)
- **Arduino IDE** + **Mu Editor**
- **Bazecor** — Dygma keyboard configurator

### Photo & Image Editing (see `photo-restoration.nix`)
- **GUI**: Pinta, GIMP, Darktable, RawTherapee, Upscayl, DigiKam, Hugin
- **CLI**: ImageMagick, G'MIC, ExifTool
- **Color management**: DisplayCAL, ArgyllCMS

### Productivity & Communication
- **Obsidian**, **LibreOffice**, **Figma**, **Hugo** (static site generator)
  - *Apostrophe (markdown) was removed 2026-10-09 — it pulled in a `python3.12-anyio` build that fails its own test suite and is absent from the binary cache. Looking for a replacement.*
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
| Hostname | nixos-dev (also `vm-guest`, `home-server`) |
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

### Opening an app on a specific COSMIC workspace

Not supported by COSMIC 1.9.0. Its shortcut actions include `Spawn("cmd")`,
`Workspace(n)` (switch to) and `MoveToWorkspace(n)` (move focused window), but
nothing that composes spawn-onto-a-workspace, and `WindowRules` has no
assign-to-workspace rule yet. Worth re-checking after a `nix flake update` —
upstream WindowRules is where such a rule would land.

## Recent Changes

Generation history (use `nix run nixpkgs#nvd -- diff /nix/var/nix/profiles/system-{N}-link /nix/var/nix/profiles/system-{N+1}-link` to inspect any pair):

| Date | Generation | What changed |
|------|-----------|--------------|
| 2026-10-14 | 226 | Pinned `catppuccin-cosmic`; applied Catppuccin Mocha to COSMIC + ghostty; added `catppuccin-whiskers`; bumped herdr 0.7.5 → 0.9.4. Also replaced `hmBase` with an `hmFor` function — as dotted keys merged with `//`, `useGlobalPkgs`/`useUserPackages`/`backupFileExtension` were being silently dropped on all four targets and had never taken effect |
| 2026-10-09 | — | Removed Apostrophe (unbuildable `anyio` dependency); COSMIC specialisation keeps `gnome-keyring` on so 1Password can store its 2FA token |
| 2026-10-08 | — | Ghostty replaced WezTerm as the default terminal (terminal-browser needs the full kitty graphics protocol) |
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
