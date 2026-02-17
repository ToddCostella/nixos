# Implementation Plan: Flakes Migration + Home Manager + 1Password Dotfiles

**Branch**: `002-nixos-homemanager-dotfiles` | **Date**: 2026-02-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-nixos-homemanager-dotfiles/spec.md`

## Summary

Migrate the NixOS configuration from channel-based to Nix flakes for reproducible builds, add Home Manager as a NixOS module for declarative dotfile management (git, zsh, tmux, SSH, AWS CLI), and integrate 1Password as the runtime secrets backend so the entire configuration is safe to commit to git.

## Technical Context

**Language/Version**: Nix (NixOS 24.05, stateVersion "24.05")
**Primary Dependencies**: nixpkgs (nixos-24.05 branch), home-manager (release-24.05 branch), 1Password GUI + CLI
**Storage**: N/A (declarative configuration files only)
**Testing**: `sudo nixos-rebuild dry-build` (syntax/evaluation), `sudo nixos-rebuild test` (non-boot validation), `sudo nixos-rebuild switch` (full apply)
**Target Platform**: NixOS x86_64-linux, single development workstation (hostname: nixos-dev)
**Project Type**: Single system configuration repository
**Performance Goals**: N/A — system configuration, not runtime software
**Constraints**: Zero regressions on existing system functionality; no secrets in committed files; single rebuild command
**Scale/Scope**: 1 host, 1 user ("todd"), ~12 existing `.nix` modules, 5 managed dotfile categories

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Assessment |
|-----------|--------|------------|
| I. Declarative Configuration | PASS | All changes are expressed in `.nix` files. Home Manager makes dotfiles declarative (improvement). No imperative state relied upon. |
| II. Test Before Apply | PASS | Workflow unchanged: dry-build → test → switch → commit. Flakes do not alter this sequence. |
| III. Modularity | PASS | New `home.nix` follows modular pattern. Home Manager config is a separate module imported from `flake.nix`. Existing modules unchanged. |
| IV. Reproducibility | PASS | Flakes + lockfile is a strict improvement over channels. All inputs pinned to exact revisions. |
| V. Simplicity | PASS with justification | Flakes + Home Manager adds structural complexity (flake.nix, home.nix, lockfile). Justified: spec requires reproducible builds (FR-001) and declarative dotfiles (FR-004), which cannot be achieved without these additions. See Complexity Tracking. |
| Security Baseline | PASS | No secrets committed. All sensitive values resolved at runtime via 1Password agent/CLI. |

**Post-Phase-1 Re-check**: PASS — no violations introduced during design. The flakes migration is now a concrete, demonstrated need (not hypothetical) since reproducibility and Home Manager integration both require it.

## Project Structure

### Documentation (this feature)

```text
specs/002-nixos-homemanager-dotfiles/
├── plan.md              # This file
├── research.md          # Phase 0 output — all technical decisions
├── data-model.md        # Phase 1 output — configuration entity model
├── quickstart.md        # Phase 1 output — migration runbook
├── contracts/           # Phase 1 output — file contracts
│   ├── flake-nix.md     # flake.nix structure contract
│   ├── home-nix.md      # home.nix structure contract
│   └── configuration-nix-changes.md  # Changes to existing configuration.nix
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
/etc/nixos/                          # NixOS configuration root (symlinked or direct)
├── flake.nix                        # NEW — flake inputs and outputs (nixpkgs + home-manager)
├── flake.lock                       # NEW — auto-generated lockfile (committed to git)
├── configuration.nix                # MODIFIED — remove system-level git/zsh ohMyZsh config,
│                                    #   add 1Password module config, disable GnuPG SSH,
│                                    #   update nix.nixPath for flakes, remove channel nixPath
├── home.nix                         # NEW — Home Manager user config for "todd"
│                                    #   (git, zsh, tmux, ssh, awscli, packages)
├── hardware-configuration.nix       # UNCHANGED — auto-generated
├── remote-terminal.nix              # MODIFIED — remove tmux config (moved to home.nix),
│                                    #   keep mosh + SSH server config
├── esp32-dev.nix                    # UNCHANGED
├── photo-restoration.nix            # UNCHANGED
├── desktop-icons.nix                # UNCHANGED
├── desktop-gnome.nix                # UNCHANGED
├── desktop-cosmic.nix               # UNCHANGED
├── playwright-dev.nix               # UNCHANGED
├── desktop-kde.nix                  # UNCHANGED (not imported)
├── desktop-cinnamon.nix             # UNCHANGED (not imported)
└── desktop-multi-de-compat.nix      # UNCHANGED (not imported)
```

**Structure Decision**: This is a NixOS system configuration repository, not a software project. The "source code" is the `.nix` configuration files at the repository root. New files (`flake.nix`, `flake.lock`, `home.nix`) are added alongside existing config files. The modular pattern (separate `.nix` files per concern) is preserved per Constitution Principle III.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Flakes (Principle V) | FR-001 requires reproducible builds with locked dependency versions. Channels do not provide pinned revisions. | Channels + manual pinning is fragile and not reproducible across machines. |
| Home Manager module (Principle V) | FR-004 requires declarative dotfile management. NixOS has no built-in mechanism for user-level config files. | Manual dotfile management (stow, chezmoi) does not integrate with NixOS rebuild and is not declarative Nix. |
| 1Password integration (Principle V) | FR-005, FR-012 require secrets never in committed files. Runtime resolution via 1Password is the only approach that satisfies both. | sops-nix/agenix add similar complexity; 1Password is already installed and used by the administrator. |
