# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a multi-host NixOS configuration repository. It manages four flake targets declaratively using **Nix flakes** and **Home Manager** (as a NixOS module):
- `nixos-dev` — Dell XPS laptop, full desktop environment
- `vm-guest` — Persistent libvirt/QEMU VM; same desktop + tools as nixos-dev, VM-adapted hardware (see `docs/vm-guest-install.md`)
- `vm-test` — Throwaway `nixos-rebuild build-vm` target (nixos-dev + `vm-test.nix`); not a real host
- `home-server` — Headless mini PC for DNS / home-lab services (hardware TBD)

## Architecture

```
nixos-config/
├── flake.nix                            # 4 targets (nixos-dev, vm-guest, vm-test, home-server)
├── flake.lock                           # Pinned dependency versions
├── hosts/
│   ├── nixos-dev/
│   │   ├── configuration.nix            # Physical-machine-only: bootloader, hugepages,
│   │   │                                #   EPP, nested virt, bluetooth, backup mount
│   │   ├── desktop-tools.nix            # SHARED desktop + tools layer (also imported by
│   │   │                                #   vm-guest): DE, dev tooling, 1Password, fonts,
│   │   │                                #   full package set, custom scripts, DE specialisations
│   │   └── hardware-configuration.nix   # Auto-generated (do not modify manually)
│   ├── vm-guest/
│   │   ├── configuration.nix            # VM-adapted hardware; imports ../nixos-dev/desktop-tools.nix
│   │   └── hardware-configuration.nix
│   └── home-server/
│       ├── configuration.nix            # Headless server config
│       └── hardware-configuration.nix   # Placeholder until hardware is known
├── modules/
│   ├── common.nix                       # Shared base: nix settings, locale, avahi, core CLI
│   ├── remote-terminal.nix              # Mosh + SSH hardening (imported by common.nix)
│   ├── desktop-gnome.nix                # GNOME desktop environment (the base DE)
│   ├── desktop-icons.nix                # Custom desktop application icons
│   ├── nordvpn.nix                      # NordVPN WireGuard (wgnord)
│   ├── playwright-dev.nix               # Playwright E2E testing dependencies
│   ├── esp32-dev.nix                    # ESP32 microcontroller development tools
│   ├── photo-restoration.nix            # Photo editing and restoration applications
│   ├── desktop-cosmic.nix               # Standalone COSMIC module — NOT imported; the live
│   │                                    #   COSMIC setup is the specialisation in desktop-tools.nix
│   ├── desktop-hyprland.nix             # Hyprland compositor (standalone; see note above)
│   ├── desktop-kde.nix                  # KDE Plasma desktop (standalone; see note above)
│   ├── desktop-cinnamon.nix             # Cinnamon desktop (standalone; not wired up)
│   └── desktop-multi-de-compat.nix      # Multi-DE compatibility layer
├── home/
│   ├── todd-base.nix                    # Headless-safe: git, zsh, herdr, SSH, AWS, CLI tools
│   ├── todd-desktop.nix                 # GUI apps (nixos-dev + vm-guest)
│   ├── mail.nix                         # Email stack: mbsync/msmtp/notmuch/aerc
│   └── *.py                             # Mail helpers (archive_old_inbox, analyze_senders, …)
├── scripts/                             # start-server.sh, start-mail.sh, home-server-install.sh,
│                                        #   vm-guest-install.sh, vm-guest-provision.sh
├── docs/                                # vm-guest-install.md, new-drives-plan.md, rack-wishlist.md
└── start-dev.sh                         # Launch herdr workspace for nixos-config work
```

### Flake & Home Manager
- `flake.nix` - Defines `nixos-dev`, `vm-guest`, `vm-test`, `home-server`
- `flake.lock` - Pinned dependency versions (committed, update with `nix flake update`)
- `home/todd-base.nix` - Home Manager config for all hosts: git, zsh, herdr, SSH, AWS CLI, CLI packages
- `home/todd-desktop.nix` - GUI packages, imported for `nixos-dev` and `vm-guest`
- Shared home-manager wiring lives in the `hmFor` function in `flake.nix`. It must
  stay a function returning ONE `home-manager` attrset: hosts merge it with `//`,
  which is shallow, so settings written as separate dotted keys
  (`home-manager.useUserPackages = ...`) get silently dropped when a host sets
  `home-manager.users.todd`. `hmFor` is also what passes `inputs` to the home
  modules via `extraSpecialArgs`.

### Module layers
- `modules/common.nix` — Imported by every host. Handles: nix settings, locale, time zone, avahi, journald, core CLI packages, and imports `remote-terminal.nix`
- `hosts/nixos-dev/desktop-tools.nix` — The shared desktop + tools layer, imported by BOTH `nixos-dev` and `vm-guest` so the two never drift. Holds the DE, dev tooling, 1Password, fonts, the full package set, the custom shell scripts, and the alternate-DE specialisations. Most package/tooling changes belong here, not in a host `configuration.nix`
- `hosts/<name>/configuration.nix` — Host-specific settings only. Sets `system.stateVersion`, `networking.hostName`, hardware/boot specifics

### Desktop environments (specialisations)
GNOME is the base DE. Hyprland, COSMIC, and KDE Plasma 6 are [NixOS specialisations](https://nixos.wiki/wiki/NixOS_specialisations) defined inline in `hosts/nixos-dev/desktop-tools.nix` (~line 489+) — selectable at boot or switched at runtime without a rebuild. The standalone `modules/desktop-*.nix` files are NOT imported; editing them has no effect on the live system.

```bash
# Switch at runtime (no reboot)
sudo /run/current-system/specialisation/cosmic/bin/switch-to-configuration switch
# ...or, when already booted into a specialisation, reach it through the profile:
sudo /nix/var/nix/profiles/system/specialisation/cosmic/bin/switch-to-configuration switch

# Back to base GNOME
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev
```

Each specialisation sets `system.nixos.tags`, so the booted one shows up in the
system name (e.g. `...-nixos-system-nixos-dev-COSMIC-26.11...`).

**Gotcha when checking what is live:** if you are booted into a specialisation,
`/run/current-system` points at the *specialisation's* store path, not the base
system that `nixos-rebuild switch` just built — and `/run/current-system/specialisation/`
is empty. That is not a failed switch. Compare against
`/nix/var/nix/profiles/system/specialisation/<name>` to confirm.

COSMIC-specific note: its specialisation deliberately leaves `gnome-keyring` ON.
Despite the name it is the de-facto org.freedesktop.secrets provider and COSMIC
ships no replacement — without it 1Password cannot save its 2FA token. See the
comment at the `cosmic.configuration` block for the full rationale.

## Key System Components

- **Hosts**: `nixos-dev` (Dell XPS laptop, `nixos-dev.local`), `vm-guest` (libvirt VM), `home-server` (headless, hardware TBD)
- **Desktop**: GNOME with GDM display manager (Wayland) is the base; COSMIC / Hyprland / KDE are specialisations (see above). Currently running COSMIC
- **Terminal**: Ghostty (default, replaced WezTerm 2026-10-08 — terminal-browser needs the full kitty graphics protocol, which WezTerm only partially implements). WezTerm is still installed, and the KDE specialisation still sets `TERMINAL = "wezterm"`. herdr for session/multiplexing (replaced tmux)
- **Theme**: Catppuccin Mocha across COSMIC and Ghostty (see Theming below)
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
| `~/.config/herdr/config.toml` | `home.file` (herdr multiplexer) |
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

## herdr Multiplexer (home/todd-base.nix)

herdr replaced tmux as the terminal multiplexer. Config is written to
`~/.config/herdr/config.toml` via `home.file` (only where the herdr overlay is
applied — nixos-dev). Reload a running server with `herdr server reload-config`.

- **Prefix**: `alt+a`
- **Theme**: `terminal` (follows the host terminal's ANSI palette — now Ghostty's)
- **Tabs** (≈ tmux windows): `alt+1..9` switches directly (no prefix), `prefix+c` new tab
- **Workspaces**: `prefix+w` then a number switches by index (order can shift);
  `prefix+g` opens the **navigator** — a name-searchable picker over spaces,
  stable regardless of reordering. Bound to the `herdr-navigator` plugin
  (`herdr-navigator.open`), overriding herdr's built-in `goto` default.
- **Splits**: `prefix+\` vertical divider (side-by-side), `prefix+-` horizontal (stacked)
- **Pane focus**: `alt+arrows` (no prefix)
- **Mouse / copy**: `mouse_capture` + `copy_on_select` on
- **vim-herdr-navigation**: `Ctrl+h/j/k/l` crosses seamlessly between Neovim splits
  and herdr panes (vim-tmux-navigator port); Neovim half at
  `~/.config/nvim/after/plugin/herdr_nav.lua` (unmanaged)
- **Notifications**: in-app herdr toasts, sound disabled

Neovim clipboard uses a **detached `wl-copy`** provider (spawned with no tty) —
herdr (0.9.4 as of 2026-10-14) does not forward inner-program OSC 52 to the outer terminal, and the
naive `wl-copy` invocation caused a resize flash on every yank.

## 1Password SSH Agent

- SSH keys managed by 1Password SSH agent — no private key files needed on disk
- Agent socket: `~/.1password/agent.sock` (configured in `programs.ssh` in `home/todd-base.nix`)
- Git commit signing via `op-ssh-sign` using key `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR93ztnY9HKCSLlFtwsdrEcwx8ovgpGhJTBB7XS2l5o`
- GnuPG SSH support is disabled (`enableSSHSupport = false`) — 1Password handles SSH exclusively

## Theming (Catppuccin Mocha)

COSMIC and Ghostty both run **Catppuccin Mocha**. The accent is Blue
(`#89b4fa`), which is also Ghostty Mocha's `palette = 4`, so terminal blue and
desktop accent agree. herdr sets `theme = terminal`, so it inherits the palette
from Ghostty automatically.

**Ghostty** is fully declarative: `theme = Catppuccin Mocha` in the
`home.file.".config/ghostty/config"` block in `home/todd-desktop.nix`. Ghostty
ships all four Catppuccin flavors itself (`ghostty +list-themes`) — nothing is
vendored.

**COSMIC is NOT declarative.** It has no theme option and explodes its theme
into ~70 per-key files under `~/.config/cosmic/com.system76.CosmicTheme.*`. What
the config pins is the *source*: the `catppuccin-cosmic` flake input
(`flake = false`, it ships only templates + prebuilt RONs) surfaced at
`~/.local/share/catppuccin-cosmic`. Applying it is a one-time manual import:

- COSMIC Settings → Desktop → Appearance → Import → `~/.local/share/catppuccin-cosmic/themes/cosmic-settings/`
- COSMIC Term → View → Color schemes → Import → `.../themes/cosmic-term/`

`catppuccin-whiskers` (in `home/todd-desktop.nix`) renders the `.tera` templates
for accent/roundness/gap combinations outside the 56 prebuilt RONs:

```bash
cd ~/.local/share/catppuccin-cosmic
whiskers templates/cosmic-settings.tera \
  --overrides='{"accent":"mauve","roundness":"square","bg_alpha":0.9}'
```

**Known gap (cosmic-comp 1.9.0):** the shipped themes target the **v1** theme
schema, but 1.9.0 writes **v2**. Colors migrate fine; transparency does not —
v1's single `is_frosted` bool became `frosted`, `frosted_panel`,
`frosted_applets`, `frosted_windows`, `frosted_maximized_apps`,
`frosted_system_interface`, plus an `alpha_map`. Expect to set frosted/blur by
hand in Appearance after importing.

## Workspaces in COSMIC

COSMIC 1.9.0 has **no built-in "open application on workspace N"** action. Its
shortcut actions (`~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/`,
defaults at `/run/current-system/sw/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/defaults`)
include `Spawn("cmd")`, `Workspace(n)` (switch to), and `MoveToWorkspace(n)`
(move focused window) — but nothing that composes spawn-onto-a-workspace. The
`com.system76.CosmicSettings.WindowRules` config exists but has no
assign-to-workspace rule in 1.9.0. Re-check after a `nix flake update`; upstream
WindowRules is where such a rule would land.

## Screenshot Tools

Use **GNOME's built-in screenshot UI** (`Print` key → Screen/Window/Selection
overlay). It captures via Mutter and copies to the clipboard; the image then
pastes normally (Neovim no longer shadows the clipboard — see the clipboard
notes in `home/todd-base.nix` / nvim `NOTES.md`).

The old custom `screenshot-area/full/window/quick` scripts (Satty annotation →
`current-screenshot.png` → clipboard) were **removed**: they wrapped
`gnome-screenshot`, which is broken on GNOME Wayland (empty X11 fallback, exits
0 but captures nothing). grim/slurp don't work on Mutter either (no
wlr-screencopy), and `org.gnome.Shell.Screenshot` DBus is AccessDenied on
GNOME 50 — so the built-in UI is the only working path.

Under the **COSMIC** specialisation this does not apply: COSMIC ships
`cosmic-screenshot` (installed by the specialisation) and `Print` is bound to it
via the `Screenshot` system action.

## Custom Shell Scripts

- `wezterm-clip2path` - Converts clipboard image to file path for Claude Code image pasting. WEZTERM ONLY: it needs a WezTerm pane id and the wezterm CLI, so it does nothing under Ghostty; no equivalent yet
- `mitm-localhost` - mitmproxy helper for capturing localhost HTTP traffic during development
- `kill-zoom` - Detect and kill all running Zoom processes (SIGTERM, then SIGKILL stragglers)
- `start-workspace` - Launch the standard working set as a herdr workspace
- `start-dev.sh` - Launch herdr workspace for nixos-config work (Claude AI + Terminal + Yazi)

The first four are `pkgs.writeShellScriptBin` definitions in
`hosts/nixos-dev/desktop-tools.nix`; `start-dev.sh` and the `scripts/` helpers
(`start-server.sh`, `start-mail.sh`, `home-server-install.sh`,
`vm-guest-install.sh`, `vm-guest-provision.sh`) are plain files in the repo.

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

# Update all flake inputs (nixpkgs + home-manager + herdr + catppuccin-cosmic)
nix flake update ~/nixos-config

# Build the persistent VM / throwaway test VM
sudo nixos-rebuild switch --flake ~/nixos-config#vm-guest
nixos-rebuild build-vm --flake ~/nixos-config#vm-test

# Evaluate every target without sudo (catches eval errors in all 4 at once)
for h in nixos-dev vm-guest vm-test home-server; do
  nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" \
    >/dev/null && echo "$h OK" || echo "$h FAIL"
done

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
- Desktop/dev packages and tooling go in `hosts/nixos-dev/desktop-tools.nix` (shared with `vm-guest`). Only genuinely physical-machine settings belong in `hosts/nixos-dev/configuration.nix`
- CLI user packages go in `home/todd-base.nix`; GUI user packages in `home/todd-desktop.nix`
- SSH server config is in `modules/remote-terminal.nix`; SSH client config is in `home/todd-base.nix`
- `flake.lock` must be committed — it pins exact dependency versions
- The internal backup drive (`nvme0n1`, formerly Debian) is mounted at `/mnt/backup-internal` — holds the local Pika/Borg backup repo
- Weekly garbage collection removes generations older than 30 days
- Journal capped at 500MB / 1 month retention
- GNOME Tracker (localsearch/tinysparql) is disabled
- `~/.secrets.env` is NOT committed — regenerate with `refresh-secrets`
- `users.users.todd.extraGroups` is NOT merged by NixOS — each host must declare the full list
- `system.stateVersion` is set per-host, NOT in `modules/common.nix`
- `modules/desktop-{cosmic,hyprland,kde,cinnamon}.nix` are NOT imported — the live alternate DEs are specialisations in `hosts/nixos-dev/desktop-tools.nix`. Editing those standalone modules changes nothing
- home-manager settings must stay inside the single `home-manager` attrset returned by `hmFor` in `flake.nix` — see the note under Flake & Home Manager for why `//` makes dotted keys unsafe
- When booted into a DE specialisation, `/run/current-system` is the specialisation's path and `/run/current-system/specialisation/` is empty; compare against `/nix/var/nix/profiles/system/specialisation/<name>` before concluding a switch failed

## Adding a New Host

1. Create `hosts/<hostname>/configuration.nix` and `hosts/<hostname>/hardware-configuration.nix`
2. Add the host to `flake.nix` following the existing pattern, using the shared `hmFor` helper for the home-manager block
3. Import `modules/common.nix` and any needed feature modules (and `hosts/nixos-dev/desktop-tools.nix` if it should share the desktop/tooling set)
4. Set `system.stateVersion` to match the NixOS installer ISO version used
5. Replace the placeholder hardware config with output of `nixos-generate-config --root /mnt`
