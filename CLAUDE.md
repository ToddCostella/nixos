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
│   ├── desktop-gnome.nix                # GNOME — the FALLBACK desktop; imported by the
│   │                                    #   gnome specialisation in desktop-tools.nix
│   ├── desktop-icons.nix                # Custom desktop application icons
│   ├── nordvpn.nix                      # NordVPN WireGuard (wgnord)
│   ├── playwright-dev.nix               # Playwright E2E testing dependencies
│   ├── esp32-dev.nix                    # ESP32 microcontroller development tools
│   ├── photo-restoration.nix            # Photo editing and restoration applications
│   ├── desktop-cosmic.nix               # Standalone COSMIC module — NOT imported; the live
│   │                                    #   COSMIC setup is inline in desktop-tools.nix
│   ├── desktop-hyprland.nix             # Hyprland — REMOVED as a specialisation 2026-10-16;
│   │                                    #   module kept on disk, imported by nothing
│   ├── desktop-kde.nix                  # KDE Plasma — REMOVED 2026-10-16; imported by nothing
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

### Desktop environments (COSMIC base + GNOME fallback)
**COSMIC is the base desktop**, configured inline in
`hosts/nixos-dev/desktop-tools.nix`. **GNOME is the single fallback**, a
specialisation in the same file that imports `modules/desktop-gnome.nix` and
forces COSMIC off. Reorganised 2026-10-16: previously GNOME was the base with
cosmic/kde/hyprland as specialisations.

KDE and Hyprland were removed. `modules/desktop-{kde,hyprland,cinnamon,multi-de-compat}.nix`
still exist on disk but are **imported by nothing** — editing them changes
nothing. PR #6 (Omarchy-flavoured Hyprland) was closed as abandoned on
2026-10-16; its `hyprland-omarchy` branch is still on the remote, and the bulk of
that work (~860 lines under `home/hyprland/`) is independent of the
base/specialisation split if Hyprland is ever revisited.

```bash
# Boot menu: the default entry is COSMIC; "NixOS - GNOME" boots the fallback.

# Runtime switch to the GNOME fallback (no reboot)
sudo /run/current-system/specialisation/gnome/bin/switch-to-configuration switch

# Back to COSMIC (the base)
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev
```

The GNOME specialisation sets `system.nixos.tags = [ "GNOME" ]`, so when it is
booted the tag shows up in the system name
(`...-nixos-system-nixos-dev-GNOME-26.11...`). The base COSMIC system carries no
tag.

**Reading the paths:** when booted into a specialisation, `/run/current-system`
is the *specialisation's* store path while `/nix/var/nix/profiles/system` is the
generation's *base* path, so the two legitimately differ and
`/run/current-system/specialisation/` is empty. Both still come from the same
generation — confirm with:

```bash
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system/specialisation/gnome   # should match
```

**Do NOT log out of a graphical session after a `nixos-rebuild switch`.**
Reboot, or stay logged in. A switch prints:

```
NOT restarting the following changed units: display-manager.service
```

That is deliberate (restarting it would kill your session), but it means the
running greeter/session keep referring to the OLD generation's store paths while
`/run/current-system` has already moved to the new one. Log out and the session
tries to exec a compositor path that no longer matches, panics, and drops you
straight back to the login screen on every attempt:

```
cosmic-session: panicked at 'failed to launch compositor:
  Os { code: 2, kind: NotFound, "No such file or directory" }': src/comp.rs:149
```

A reboot clears it, because everything then starts from the new generation.
Seen 2026-10-16 (gen 226 -> 227 switched at 12:29, logout at 12:31 bounced
twice). The same trap applies under GNOME; it is not COSMIC-specific.

**Known COSMIC 1.9.0 bug — panel applets die on resume from suspend.** After a
long suspend, every applet can be SIGKILLed a few seconds after cgroup thaw and
never restart:

```
cosmic-panel[...]: com.system76.CosmicAppletBattery: exited with code 137   # 137 = SIGKILL
```

`cosmic-comp` survives, so the mouse and existing windows keep working, but
`cosmic-panel` hosts the app-list and workspace buttons — so the app switcher
and launcher UI are simply gone. This is not memory pressure (the
`OOM killer disabled/enabled` pair in the log brackets every suspend and is
routine). Nothing in this repo causes or can fix it; it is upstream.

Recovery is awkward, because `cosmic-panel` is **not** a systemd service — there
is no `cosmic-panel.service` or `.scope`. `cosmic-session` spawns it directly and
hands it an inherited fd (`PANEL_NOTIFICATIONS_FD`), so relaunching
`cosmic-panel` by hand does not reproduce a working panel. In practice:

- If a `nixos-rebuild switch` has happened since boot, **reboot** (logging out
  hits the trap above).
- Otherwise log out and back in, which restarts `cosmic-session` and with it the
  panel.
- Keyboard shortcuts bound in `cosmic-comp` (workspace switching, `prefix`-style
  binds) keep working while the panel is dead, since the compositor survives —
  useful for saving work before restarting the session.

COSMIC-specific note: `gnome-keyring` is deliberately enabled in the **base**
config even though GNOME is no longer the base desktop. Despite the name it is
the de-facto org.freedesktop.secrets provider and COSMIC ships no replacement —
without it 1Password cannot save its 2FA token. See the comment next to
`services.gnome.gnome-keyring.enable` in `desktop-tools.nix` for the full
rationale.

## Key System Components

- **Hosts**: `nixos-dev` (Dell XPS laptop, `nixos-dev.local`), `vm-guest` (libvirt VM), `home-server` (headless, hardware TBD)
- **Desktop**: COSMIC (Wayland) is the base desktop, with GDM as the display manager; GNOME is the one fallback specialisation (see above). KDE and Hyprland were removed 2026-10-16
- **Terminal**: Ghostty (default, replaced WezTerm 2026-10-08 — terminal-browser needs the full kitty graphics protocol, which WezTerm only partially implements). WezTerm is still installed but is no longer the default anywhere; `TERMINAL = "ghostty"` is set by the base config and by `modules/desktop-gnome.nix`. herdr for session/multiplexing (replaced tmux)
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
- `modules/desktop-{cosmic,hyprland,kde,cinnamon,multi-de-compat}.nix` are NOT imported — COSMIC is configured inline in `hosts/nixos-dev/desktop-tools.nix` and GNOME comes in via the `gnome` specialisation there. Editing those standalone modules changes nothing
- home-manager settings must stay inside the single `home-manager` attrset returned by `hmFor` in `flake.nix` — see the note under Flake & Home Manager for why `//` makes dotted keys unsafe
- `nixos-rebuild switch` builds the specialisations too, and each gets its own boot-menu entry for that generation — rebuild, reboot, pick the COSMIC entry. When booted into a specialisation, `/run/current-system` is the specialisation's path while `/nix/var/nix/profiles/system` is the base; they differ by design and both come from the same generation

## Adding a New Host

1. Create `hosts/<hostname>/configuration.nix` and `hosts/<hostname>/hardware-configuration.nix`
2. Add the host to `flake.nix` following the existing pattern, using the shared `hmFor` helper for the home-manager block
3. Import `modules/common.nix` and any needed feature modules (and `hosts/nixos-dev/desktop-tools.nix` if it should share the desktop/tooling set)
4. Set `system.stateVersion` to match the NixOS installer ISO version used
5. Replace the placeholder hardware config with output of `nixos-generate-config --root /mnt`
