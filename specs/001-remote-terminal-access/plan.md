# Implementation Plan: Remote Terminal Access from iOS

**Branch**: `001-remote-terminal-access` | **Date**: 2026-02-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-remote-terminal-access/spec.md`

## Summary

Enable remote terminal access from iPhone/iPad to the NixOS
desktop by migrating pane management from WezTerm to tmux,
adding Mosh for resilient connections, and hardening SSH.
WezTerm remains the desktop terminal emulator but launches
directly into tmux. iOS devices connect via Mosh and attach
to the same tmux sessions.

## Technical Context

**Language/Version**: Nix (NixOS configuration language)
**Primary Dependencies**: tmux, mosh, openssh, wl-clipboard
**Storage**: N/A (no persistent data beyond tmux sessions)
**Testing**: `sudo nixos-rebuild dry-build` for syntax;
  manual verification per quickstart.md
**Target Platform**: NixOS (Linux 6.12.x, x86_64)
**Project Type**: Single NixOS module
**Performance Goals**: <10s connection time on LAN; real-time
  terminal interaction with no perceptible lag
**Constraints**: Local network only; declarative NixOS config;
  no secrets in repo
**Scale/Scope**: Single user, single machine, 1-2 iOS clients

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after
Phase 1 design.*

| Principle                   | Status | Notes                                         |
|-----------------------------|--------|-----------------------------------------------|
| I. Declarative Config       | PASS   | All changes in `.nix` files                   |
| II. Test Before Apply       | PASS   | dry-build validation in workflow               |
| III. Modularity             | PASS   | New `remote-terminal.nix` module               |
| IV. Reproducibility         | PASS   | Uses upstream NixOS packages only              |
| V. Simplicity               | PASS   | Minimal config; upstream options; no overlays  |
| Operational: Single machine | PASS   | Targets one workstation                        |
| Operational: Security       | PASS   | No secrets in repo; key-only SSH               |

No violations. No complexity justification needed.

## Project Structure

### Documentation (this feature)

```text
specs/001-remote-terminal-access/
├── plan.md              # This file
├── research.md          # Phase 0: technology decisions
├── data-model.md        # Phase 1: entity mapping
├── quickstart.md        # Phase 1: usage guide
├── contracts/
│   └── nix-module-contract.md  # Module interface spec
└── checklists/
    └── requirements.md  # Spec quality validation
```

### Source Code (repository root)

```text
remote-terminal.nix      # New NixOS module (tmux + mosh + SSH hardening)
configuration.nix        # Modified: add import, update openssh settings
```

**Structure Decision**: This is a NixOS configuration change,
not a software project. The deliverable is a single new `.nix`
module imported by `configuration.nix`, following the same
pattern as `esp32-dev.nix`, `playwright-dev.nix`, and other
existing modules. No `src/` or `tests/` directories needed.

## Complexity Tracking

No constitution violations. Table intentionally left empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none)    |            |                                     |

## Implementation Details

### New File: `remote-terminal.nix`

This module configures three concerns:

**1. tmux** (`programs.tmux`):
- Prefix: Alt-a (`M-a` via extraConfig; bypasses `shortcut`
  option which only supports Ctrl combos)
- Vi key mode with mouse support
- True color terminal (`tmux-256color` + RGB override)
- Window switching: `Alt+number` (no prefix), matching
  existing WezTerm `Alt+number` tab habit
- Pane splitting: `|` vertical, `-` horizontal (keeps cwd)
- Pane navigation: `Alt-Arrow` (no prefix) + `Ctrl-a h/j/k/l`
- Plugins: sensible, yank, resurrect, continuum, tokyo-night-tmux
- Clipboard: `wl-copy` for Wayland
- Theme: tokyo-night-tmux (night variant, from nixpkgs)
- `newSession = true` for auto-create on attach
- `escapeTime = 0` for vim/neovim compatibility

**2. Mosh** (`programs.mosh`):
- Enable with default settings
- Firewall auto-opens UDP 60000-61000

**3. SSH Hardening** (`services.openssh.settings`):
- Disable password authentication
- Disable keyboard-interactive authentication
- Disable root login
- Restrict to user `todd`

### Modified File: `configuration.nix`

- Add `./remote-terminal.nix` to imports list
- Remove bare `services.openssh.enable = true;` (moved to
  module with hardening)

### User Config (not NixOS-managed): `~/.wezterm.lua`

- Set `default_prog` to `tmux new-session -As main`
- Disable WezTerm tab bar
- Documented in quickstart.md as a manual step

## Post-Phase 1 Constitution Re-Check

| Principle              | Status | Notes                            |
|------------------------|--------|----------------------------------|
| I. Declarative Config  | PASS   | Single module + import change    |
| II. Test Before Apply  | PASS   | dry-build before switch          |
| III. Modularity        | PASS   | Dedicated module, clear scope    |
| IV. Reproducibility    | PASS   | All upstream packages            |
| V. Simplicity          | PASS   | ~60 lines of Nix config total    |

All gates pass. Ready for task generation.
