# Research: Flakes Migration + Home Manager + 1Password Secrets

**Feature**: 002-nixos-homemanager-dotfiles
**Date**: 2026-02-17
**Status**: Complete — all NEEDS CLARIFICATION resolved

---

## R-001: Flake Structure for Single-Host NixOS + Home Manager

**Decision**: Create `flake.nix` with two inputs (`nixpkgs` pinned to `nixos-24.05`, `home-manager` pinned to `release-24.05`). Use `inputs.nixpkgs.follows` for home-manager. Output: single `nixosConfigurations.nixos-dev`.

**Rationale**: This is the canonical pattern from the NixOS & Flakes Book and Misterio77's starter configs. The `follows` directive forces home-manager to share the system's nixpkgs, preventing version mismatch and double evaluation. The hostname `nixos-dev` matches the existing `networking.hostName`, so `sudo nixos-rebuild switch` auto-discovers the flake at `/etc/nixos/flake.nix` with zero command-line changes.

**Alternatives considered**:
- Standalone home-manager (separate `home-manager switch` command) — rejected per clarification Q4.
- flake-parts framework — overkill for single host.
- Pin to nixos-unstable — not needed; stateVersion 24.05 is the current release.

---

## R-002: Module Compatibility Under Flakes

**Decision**: Existing modules (`{ config, pkgs, ... }: { ... }`) work under flakes without modification. No changes to any `.nix` module file contents.

**Rationale**: The NixOS module system's argument injection is unchanged by flakes. `pkgs`, `config`, `lib`, `options`, and `modulesPath` are automatically provided. Verified against all existing modules in the repository.

**Critical gotchas**:
1. **Git tracking mandatory**: Every `.nix` file must be at least `git add`-ed. Untracked files are invisible to flake evaluation.
2. **No angle-bracket imports**: `import <nixpkgs>` fails under pure evaluation. None of the current modules use this.
3. **Do NOT set `nixpkgs.pkgs`**: Setting `nixpkgs.pkgs` explicitly in flake.nix silently ignores all `nixpkgs.config.*` settings (including `allowUnfree`). Use `nixpkgs.lib.nixosSystem` and let it construct pkgs.
4. **Pass flake inputs via `specialArgs`**: If modules need `inputs` (e.g., for NIX_PATH), use `specialArgs = { inherit inputs; }`.

---

## R-003: nixos-rebuild Command After Flakes

**Decision**: `sudo nixos-rebuild switch` continues to work unchanged when `flake.nix` is at `/etc/nixos/flake.nix` and the `nixosConfigurations` key matches the hostname.

**Rationale**: `nixos-rebuild` checks for `/etc/nixos/flake.nix` and uses flake mode automatically. The `#nixos-dev` suffix is auto-detected from the running hostname. The "dirty tree" warning is harmless and expected.

**Alternatives considered**:
- Moving config to `~/nixos-config` — good future step but adds complexity during initial migration. Defer.

---

## R-004: NIX_PATH and Flake Registry

**Decision**: Replace current `nix.nixPath` (pointing at channels) with flake-input-based path. Pass `inputs` via `specialArgs` and set both `nix.nixPath` and `nix.registry.nixpkgs.flake` to `inputs.nixpkgs`.

**Rationale**: After flakes migration, the channel path becomes stale. Pinning NIX_PATH to the flake's nixpkgs ensures `nix-shell -p` and `nix run nixpkgs#` both use the same package set as the system.

---

## R-005: Channel Removal

**Decision**: Remove channels only AFTER confirming flake-based build, switch, and reboot succeed. Use `sudo nix-channel --remove nixos` and set `nix.channel.enable = false` in config.

**Rationale**: Channels are fully replaced by `flake.lock`. Keeping them creates confusion about which nixpkgs is actually in use.

---

## R-006: Home Manager as NixOS Module via Flakes

**Decision**: Add `home-manager.nixosModules.home-manager` to the modules list. Set `useGlobalPkgs = true`, `useUserPackages = true`, `backupFileExtension = "hm-backup"`. User config in separate `home.nix` file.

**Key settings**:
- `useGlobalPkgs = true` — shares system's pkgs (with `allowUnfree`) with Home Manager.
- `useUserPackages = true` — installs user packages to `/etc/profiles/per-user/todd`.
- `backupFileExtension = "hm-backup"` — renames conflicting dotfiles instead of failing during first activation.
- `home.stateVersion = "24.05"` — matches current system.

---

## R-007: Lockfile Management

**Decision**: Commit `flake.lock` to git. Use `nix flake update` for all inputs, `nix flake update nixpkgs` for selective updates.

**Typical workflow**: `nix flake update` → `sudo nixos-rebuild switch` → if success, `git add flake.lock && git commit`. If failure, `git checkout flake.lock`.

---

## R-008: Zsh — System-Level vs Home Manager

**Decision**: Keep `programs.zsh.enable = true` at system level (registers zsh in `/etc/shells`). Move Oh-My-Zsh config to Home Manager's `programs.zsh.oh-my-zsh`. Remove system-level `programs.zsh.ohMyZsh` block and `oh-my-zsh` package from `environment.systemPackages`.

**Rationale**: System-level zsh registration is required for login shell; Home Manager cannot modify `/etc/shells`. Oh-My-Zsh must be in exactly one place to avoid conflicting `.zshrc` generation.

---

## R-009: Git with 1Password SSH Commit Signing

**Decision**: Use Home Manager `programs.git` with:
- `signing.format = "ssh"`
- `signing.signer = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}"`
- `signing.key` = SSH public key string from 1Password
- `signing.signByDefault = true`

**Critical NixOS detail**: `op-ssh-sign` is NOT at `/opt/1Password/op-ssh-sign` (standard Linux path). It's bundled in the `_1password-gui` Nix package. Reference via `lib.getExe'`.

Remove system-level `programs.git` block to avoid conflicts with Home Manager-generated `~/.config/git/config`.

---

## R-010: Tmux with Catppuccin Theme

**Decision**: Move tmux config from system-level `remote-terminal.nix` to Home Manager `programs.tmux`. Use native Nix plugin management via `programs.tmux.plugins` (NOT TPM). Use `tmuxPlugins.catppuccin` from nixpkgs.

**Plugin ordering**: Catppuccin must be loaded BEFORE resurrect and continuum (it modifies the status bar).

**System-level tmux in remote-terminal.nix**: Remove tmux configuration from this file; keep mosh and SSH config there.

---

## R-011: SSH Config with 1Password Agent

**Decision**: Use Home Manager `programs.ssh` with `matchBlocks."*".extraOptions.IdentityAgent = "~/.1password/agent.sock"` or `extraConfig` for the 1Password agent. Socket path: `~/.1password/agent.sock`.

**GnuPG conflict**: Change `programs.gnupg.agent.enableSSHSupport = false` (currently `true`). GPG agent remains for non-SSH operations. No side effects.

---

## R-012: AWS CLI Config with 1Password Credentials

**Decision**: Use Home Manager `programs.awscli` module with:
- `programs.awscli.settings` for `~/.aws/config` (profile names, regions, output formats)
- `credential_process` referencing `op --cache inject --in-file ~/.aws/1pw/<profile>.json`
- Manage JSON template files containing `{{ op://vault/item/field }}` placeholders via `home.file`

**Rationale**: The `credential_process` approach works universally with all AWS SDKs, CDK, Terraform, etc. 1Password Shell Plugins only cover the `aws` CLI itself.

---

## R-013: 1Password NixOS Module Configuration

**Decision**: Use `programs._1password.enable = true` (CLI with SUID wrapper) and `programs._1password-gui = { enable = true; polkitPolicyOwners = [ "todd" ]; }`. Remove `_1password-gui` from `environment.systemPackages`.

**Rationale**: The NixOS modules set up SUID wrappers, polkit policies, and native messaging host registrations. Raw package installation in `systemPackages` is insufficient for CLI <-> GUI integration.

---

## R-014: Graceful Degradation Without 1Password

**Decision**: All secret references are runtime-only. `nixos-rebuild switch` always succeeds regardless of 1Password state. When 1Password is locked/not running:
- AWS CLI: clear error from `credential_process` failure
- SSH: clear error (socket not found)
- Git signing: clear error from `op-ssh-sign`

No silent fallbacks. Clear error messages tell the user to unlock 1Password.

---

## R-015: Package Migration Strategy

**Decision**: Two-tier approach:
- **System-level** (`environment.systemPackages`): Infrastructure, root-needed tools, hardware-coupled packages, fonts, custom shell scripts, virtualization tools.
- **Home Manager** (`home.packages` or program modules): User-facing dev tools, applications, CLI utilities.

**Program modules** (prefer over raw `home.packages`): `programs.git`, `programs.zsh`, `programs.tmux`, `programs.awscli`, `programs.ssh`, `programs.fzf`, `programs.direnv`, `programs.atuin`, `programs.zoxide`, `programs.bat`, `programs.yazi`.

**Neovim**: Use `home.packages = [ pkgs.neovim ]` (NOT `programs.neovim`) to avoid managing `~/.config/nvim/`.

---

## Sources

- NixOS & Flakes Book (nixos-and-flakes.thiscute.world)
- Misterio77/nix-starter-configs (github.com)
- NixOS Wiki - Flakes, 1Password, Zsh (wiki.nixos.org)
- Home Manager Manual (nix-community.github.io/home-manager)
- 1Password Developer Docs — SSH Agent, CLI, Git Signing (developer.1password.com)
- NixOS Discourse community discussions
- nixpkgs source: _1password-gui.nix, gnupg.nix modules
