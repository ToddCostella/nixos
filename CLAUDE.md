# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a multi-host NixOS configuration repository. It manages two hosts declaratively using **Nix flakes** and **Home Manager** (as a NixOS module):
- `nixos-dev` — Dell XPS laptop, full desktop environment
- `home-server` — Headless mini PC for DNS / home-lab services (hardware TBD)

## Architecture

```
nixos-config/
├── flake.nix                            # Two hosts, split home modules
├── flake.lock                           # Pinned dependency versions
├── hosts/
│   ├── nixos-dev/
│   │   ├── configuration.nix            # Laptop-specific config
│   │   └── hardware-configuration.nix   # Auto-generated (do not modify manually)
│   └── home-server/
│       ├── configuration.nix            # Headless server config
│       └── hardware-configuration.nix   # Placeholder until hardware is known
├── modules/
│   ├── common.nix                       # Shared base: nix settings, locale, avahi, core CLI
│   ├── remote-terminal.nix              # Mosh + SSH hardening (imported by common.nix)
│   ├── desktop-gnome.nix                # GNOME desktop environment
│   ├── desktop-icons.nix                # Custom desktop application icons
│   ├── playwright-dev.nix               # Playwright E2E testing dependencies
│   ├── esp32-dev.nix                    # ESP32 microcontroller development tools
│   ├── photo-restoration.nix            # Photo editing and restoration applications
│   ├── desktop-cosmic.nix               # COSMIC desktop (commented out — not in current nixpkgs)
│   ├── desktop-hyprland.nix             # Hyprland compositor
│   ├── desktop-kde.nix                  # KDE Plasma desktop
│   ├── desktop-cinnamon.nix             # Cinnamon desktop
│   └── desktop-multi-de-compat.nix      # Multi-DE compatibility layer
└── home/
    ├── todd-base.nix                    # Headless-safe: git, zsh, tmux, SSH, AWS, CLI tools
    └── todd-desktop.nix                 # GUI apps only (nixos-dev)
```

### Flake & Home Manager
- `flake.nix` - Defines both `nixos-dev` and `home-server` nixosConfigurations
- `flake.lock` - Pinned dependency versions (committed, update with `nix flake update`)
- `home/todd-base.nix` - Home Manager config for all hosts: git, zsh, tmux, SSH, AWS CLI, CLI packages
- `home/todd-desktop.nix` - GUI packages imported only for `nixos-dev`

### Module layers
- `modules/common.nix` — Imported by both hosts. Handles: nix settings, locale, time zone, avahi, journald, core CLI packages, and imports `remote-terminal.nix`
- `hosts/<name>/configuration.nix` — Host-specific settings. Sets `system.stateVersion`, `networking.hostName`, and imports relevant feature modules from `../../modules/`

## Key System Components

- **Hosts**: `nixos-dev` (Dell XPS laptop, `nixos-dev.local`), `home-server` (headless, hardware TBD)
- **Desktop**: GNOME with GDM display manager (Wayland) — nixos-dev only
- **Terminal**: WezTerm (default), tmux for session management
- **Shell**: zsh with oh-my-zsh (robbyrussell theme) — configured in `home/todd-base.nix`
- **Virtualization**: Docker (auto-start) + QEMU/KVM/libvirtd with nested virtualization — nixos-dev only
- **Audio**: PipeWire (ALSA, PulseAudio compat, JACK) — nixos-dev only
- **User**: Primary user "todd" — groups: networkmanager, wheel, docker, dialout, libvirtd (nixos-dev)

## Home Manager (home/)

All user-level dotfiles are managed declaratively. Changes apply atomically with `sudo nixos-rebuild switch`.

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

### Shell aliases (defined in home/todd-base.nix)
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
2. Add `op://vault/item/field` reference to `~/.secrets.env.tpl` in `home/todd-base.nix` (or a new `home.file` template)
3. Rebuild and run `refresh-secrets`

## tmux Configuration (home/todd-base.nix)

- **Prefix**: `Alt-a` (M-a)
- **Theme**: Tokyo Night (night style)
- **Plugins**: catppuccin, sensible, yank, resurrect, continuum, tmux-sessionx
- **Session restore**: continuum auto-save every 15 min, auto-restore on start
- **Session switcher**: tmux-sessionx bound to `o`, zoxide mode, custom paths
- **Key bindings**: Alt+number (window switch), Alt+arrows (pane nav), `|`/`-` (split)
- **Clipboard**: wl-copy (Wayland)

## 1Password SSH Agent

- SSH keys managed by 1Password SSH agent — no private key files needed on disk
- Agent socket: `~/.1password/agent.sock` (configured in `programs.ssh` in `home/todd-base.nix`)
- Git commit signing via `op-ssh-sign` using key `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR93ztnY9HKCSLlFtwsdrEcwx8ovgpGhJTBB7XS2l5o`
- GnuPG SSH support is disabled (`enableSSHSupport = false`) — 1Password handles SSH exclusively

## Screenshot Tools

Custom shell scripts installed as system packages (nixos-dev only):
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

- Open TCP ports: 3000/8080 (nixos-dev: Vite dev server + WebSocket/mitmproxy), 53/80 (home-server: DNS/HTTP)
- mDNS enabled via Avahi on all hosts
- SSH: key-only auth, no root login, allows user `todd`
- Mosh: enabled (auto-opens UDP 60000-61000)

## Common Commands

### System Management
```bash
# Apply configuration changes (requires sudo) — applies BOTH system and home manager
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev

# Dry-run to check for syntax errors
sudo nixos-rebuild dry-build --flake ~/nixos-config#nixos-dev

# Test without making default
sudo nixos-rebuild test --flake ~/nixos-config#nixos-dev

# Rollback to previous generation
sudo nixos-rebuild rollback

# Update all flake inputs (nixpkgs + home-manager)
nix flake update ~/nixos-config

# Deploy to home-server remotely (once hardware is ready)
nixos-rebuild switch --flake ~/nixos-config#home-server \
  --target-host todd@10.0.0.8 --sudo
```

### Secrets
```bash
# Regenerate ~/.secrets.env from 1Password
refresh-secrets

# Test AWS credential resolution
aws sts get-caller-identity --profile toddcostella
```

## Development Workflow

1. Edit the relevant `.nix` file (a module in `modules/`, a host config in `hosts/`, or `home/`)
2. Test with `sudo nixos-rebuild dry-build --flake ~/nixos-config#nixos-dev`
3. Apply with `sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev`
4. Commit and push after successful application

## Important Notes

- Never modify `hosts/nixos-dev/hardware-configuration.nix` — it's auto-generated
- Shared settings (locale, nix gc, avahi, etc.) go in `modules/common.nix`
- Laptop/desktop packages go in `hosts/nixos-dev/configuration.nix`
- CLI user packages go in `home/todd-base.nix`; GUI user packages in `home/todd-desktop.nix`
- SSH server config is in `modules/remote-terminal.nix`; SSH client config is in `home/todd-base.nix`
- `flake.lock` must be committed — it pins exact dependency versions
- The Debian partition is mounted at `/mnt/debian` (nvme0n1p2)
- Weekly garbage collection removes generations older than 30 days
- Journal capped at 500MB / 1 month retention
- GNOME Tracker (localsearch/tinysparql) is disabled
- `~/.secrets.env` is NOT committed — regenerate with `refresh-secrets`
- `users.users.todd.extraGroups` is NOT merged by NixOS — each host must declare the full list
- `system.stateVersion` is set per-host, NOT in `modules/common.nix`

## Adding a New Host

1. Create `hosts/<hostname>/configuration.nix` and `hosts/<hostname>/hardware-configuration.nix`
2. Add the host to `flake.nix` following the existing pattern
3. Import `modules/common.nix` and any needed feature modules
4. Set `system.stateVersion` to match the NixOS installer ISO version used
5. Replace the placeholder hardware config with output of `nixos-generate-config --root /mnt`
