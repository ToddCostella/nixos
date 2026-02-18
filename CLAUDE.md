# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS system configuration repository for a development environment on a Dell XPS laptop (hostname: `nixos-dev`). It contains declarative system configuration files that define the entire system state, including packages, services, and user settings. The system uses **Nix flakes** for reproducible builds and **Home Manager** (as a NixOS module) for declarative dotfile management.

## Architecture

### System modules (imported by `configuration.nix`)
- `configuration.nix` - Main NixOS configuration: system packages, services, hardware, virtualization
- `hardware-configuration.nix` - Auto-generated hardware config (do not modify manually)
- `remote-terminal.nix` - Mosh + SSH server hardening (tmux moved to home.nix)
- `desktop-gnome.nix` - GNOME desktop environment
- `desktop-icons.nix` - Custom desktop application icons
- `playwright-dev.nix` - Playwright E2E testing dependencies (system libraries for Chromium)
- `esp32-dev.nix` - ESP32 microcontroller development tools
- `photo-restoration.nix` - Photo editing and restoration applications
- `desktop-cosmic.nix` - COSMIC desktop (commented out — not available in current nixpkgs)

### Flake & Home Manager
- `flake.nix` - Flake inputs (nixpkgs unstable + home-manager/master), wraps `configuration.nix` and `home.nix`
- `flake.lock` - Pinned dependency versions (committed, update with `nix flake update`)
- `home.nix` - Home Manager config for user "todd": git, zsh, tmux, SSH, AWS CLI, packages, aliases

## Key System Components

- **Hostname**: `nixos-dev` (accessible as `nixos-dev.local` via mDNS)
- **Desktop**: GNOME with GDM display manager (Wayland)
- **Terminal**: WezTerm (default), tmux for session management
- **Shell**: zsh with oh-my-zsh (robbyrussell theme) — configured in `home.nix`
- **Virtualization**: Docker (auto-start) + QEMU/KVM/libvirtd with nested virtualization
- **Audio**: PipeWire (ALSA, PulseAudio compat, JACK)
- **User**: Primary user "todd" — groups: networkmanager, wheel, docker, dialout, libvirtd

## Home Manager (home.nix)

All user-level dotfiles are managed declaratively in `home.nix`. Changes here apply atomically with `sudo nixos-rebuild switch`.

### Managed dotfiles
| File | Tool |
|------|------|
| `~/.config/git/config` | `programs.git` |
| `~/.zshrc` | `programs.zsh` |
| `~/.config/tmux/tmux.conf` | `programs.tmux` |
| `~/.ssh/config` | `programs.ssh` |
| `~/.aws/config` + `~/.aws/credentials` | `programs.awscli` |
| `~/.aws/1pw/*.json` | `home.file` (1Password inject templates) |
| `~/.secrets.env.tpl` | `home.file` (API key template) |
| `~/.ssh/allowed_signers` | `home.file` |

### Shell aliases (defined in home.nix)
- `lg` — lazygit
- `acv` — activate Python venv
- `db/dbf/dbb` — navigate to buoyancy-platform dirs
- `dc` — docker compose watch backend
- `nb` — npm run dev
- `sx` — tmux-sessionx session manager
- `refresh-secrets` — regenerate `~/.secrets.env` from 1Password templates

## Secrets Management (1Password)

Secrets are **never stored in committed files**. All sensitive values are resolved at runtime via the 1Password CLI.

### Pattern
- `op://vault/item/field` URIs in `home.file` templates (safe to commit)
- `credential_process` in AWS credentials config calls `op --cache inject`
- `~/.secrets.env.tpl` contains API key references, injected to `~/.secrets.env` on demand

### AWS credentials
All profiles use `credential_process` — keys stored in 1Password `Private` vault:
- `default` → `op://Private/AWS toddcostella/...`
- `toddcostella` → `op://Private/AWS toddcostella/...`
- `buoyancy-dev` → `op://Private/AWS buoyancy-dev/...`
- `buoyancy-root` → `op://Private/AWS buoyancy-root/...`

### API keys
- `ANTHROPIC_API_KEY` → `op://Private/Anthropic API Key/api-key`
- Run `refresh-secrets` to inject into `~/.secrets.env` (sourced automatically by zsh)

### Adding a new secret
1. Add the value to 1Password
2. Add `op://vault/item/field` reference to `~/.secrets.env.tpl` in `home.nix` (or a new `home.file` template)
3. Rebuild and run `refresh-secrets`

## tmux Configuration (home.nix)

- **Prefix**: `Alt-a` (M-a)
- **Theme**: Tokyo Night (night style)
- **Plugins**: catppuccin, sensible, yank, resurrect, continuum, tmux-sessionx
- **Session restore**: continuum auto-save every 15 min, auto-restore on start
- **Session switcher**: tmux-sessionx bound to `o`, zoxide mode, custom paths
- **Key bindings**: Alt+number (window switch), Alt+arrows (pane nav), `|`/`-` (split)
- **Clipboard**: wl-copy (Wayland)

## 1Password SSH Agent

- SSH keys managed by 1Password SSH agent — no private key files needed on disk
- Agent socket: `~/.1password/agent.sock` (configured in `programs.ssh` in `home.nix`)
- Git commit signing via `op-ssh-sign` using key `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR93ztnY9HKCSLlFtwsdrEcwx8ovgpGhJTBB7XS2l5o`
- GnuPG SSH support is disabled (`enableSSHSupport = false`) — 1Password handles SSH exclusively

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
- `start-dev.sh` - Launch tmux session for nixos-config work (Claude AI + Terminal + Yazi)

## Network & Firewall

- Open TCP ports: 3000 (Vite dev server), 8080 (WebSocket backend / mitmproxy)
- mDNS enabled via Avahi (`nixos-dev.local`)
- SSH: key-only auth, no root login, allows user `todd`
- Mosh: enabled (auto-opens UDP 60000-61000)

## Common Commands

### System Management
```bash
# Apply configuration changes (requires sudo) — applies BOTH system and home.nix
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev

# Dry-run to check for syntax errors
sudo nixos-rebuild dry-build --flake ~/nixos-config#nixos-dev

# Test without making default
sudo nixos-rebuild test --flake ~/nixos-config#nixos-dev

# Rollback to previous generation
sudo nixos-rebuild rollback

# Update all flake inputs (nixpkgs + home-manager)
nix flake update ~/nixos-config
```

### Secrets
```bash
# Regenerate ~/.secrets.env from 1Password
refresh-secrets

# Test AWS credential resolution
aws sts get-caller-identity --profile toddcostella
```

## Development Workflow

1. Edit the relevant `.nix` file (`configuration.nix`, `home.nix`, or a module)
2. Test with `sudo nixos-rebuild dry-build --flake ~/nixos-config#nixos-dev`
3. Apply with `sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev`
4. Commit and push after successful application

## Important Notes

- Never modify `hardware-configuration.nix` — it's auto-generated
- System packages go in `environment.systemPackages` in `configuration.nix`
- User packages and dotfiles go in `home.nix`
- SSH server config is in `remote-terminal.nix`; SSH client config is in `home.nix`
- `flake.lock` must be committed — it pins exact dependency versions
- The Debian partition is mounted at `/mnt/debian` (nvme0n1p2)
- Weekly garbage collection removes generations older than 30 days
- Journal capped at 500MB / 1 month retention
- GNOME Tracker (localsearch/tinysparql) is disabled
- `~/.secrets.env` is NOT committed — regenerate with `refresh-secrets`
