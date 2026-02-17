# Tasks: Flakes Migration + Home Manager + 1Password Dotfiles

**Input**: Design documents from `/specs/002-nixos-homemanager-dotfiles/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Not requested in spec — test tasks omitted. Validation is performed via `nixos-rebuild dry-build` and `nixos-rebuild switch` checkpoints.

**Organization**: Tasks grouped by user story (US1-US4) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Enable flakes in the repository and prepare for migration without changing system behavior.

- [ ] T001 Create `flake.nix` at repository root with nixpkgs (nixos-24.05) and home-manager (release-24.05) inputs, wrapping existing `./configuration.nix` — initially WITHOUT Home Manager module in `flake.nix`
- [ ] T002 Update `configuration.nix` function signature from `{ config, pkgs, ... }:` to `{ config, pkgs, inputs, ... }:` to accept flake inputs via specialArgs in `configuration.nix`
- [ ] T003 Stage all files for flake evaluation: `git add flake.nix` (existing `.nix` files are already tracked)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Migrate nix.nixPath and flake registry to use flake inputs, and switch the 1Password installation from raw package to NixOS modules. These changes are required by ALL user stories.

**CRITICAL**: No user story work can begin until this phase is complete and validated.

- [ ] T004 Replace channel-based `nix.nixPath` (lines 582-585) with `nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]` and add `nix.registry.nixpkgs.flake = inputs.nixpkgs` in `configuration.nix`
- [ ] T005 [P] Replace `_1password-gui` in `environment.systemPackages` (line 251) with NixOS module config: add `programs._1password.enable = true` and `programs._1password-gui = { enable = true; polkitPolicyOwners = [ "todd" ]; }` in `configuration.nix`
- [ ] T006 [P] Change `programs.gnupg.agent.enableSSHSupport` from `true` to `false` (line 536) in `configuration.nix` — 1Password SSH agent will handle SSH keys
- [ ] T007 Validate flake-based build with `sudo nixos-rebuild dry-build` — must succeed with zero errors before proceeding

**Checkpoint**: Flake-based build validates successfully. System can be rebuilt with `sudo nixos-rebuild switch`. All existing functionality preserved (FR-002, FR-003).

---

## Phase 3: User Story 1 — Reproducible System Builds with Flakes (Priority: P1)

**Goal**: Lock all dependency versions in a committed lockfile so builds are reproducible across machines and time.

**Independent Test**: Run `sudo nixos-rebuild switch`, verify system boots with all packages/services intact, verify `flake.lock` exists with pinned revisions, rebuild a second time to confirm identical result.

### Implementation for User Story 1

- [ ] T008 [US1] Generate lockfile by running `nix flake lock` to create `flake.lock` with pinned nixpkgs and home-manager revisions at repository root
- [ ] T009 [US1] Apply configuration with `sudo nixos-rebuild switch` and verify: desktop environment loads, Docker runs, all packages available, all modules functional
- [ ] T010 [US1] Verify reproducibility: rebuild a second time without changes and confirm identical build result
- [ ] T011 [US1] Stage and commit `flake.nix`, `flake.lock`, and modified `configuration.nix` to git

**Checkpoint**: US1 complete — system builds are reproducible via lockfile. `sudo nixos-rebuild switch` works from flake. All acceptance scenarios (AS 1.1-1.4) satisfied. Dependency updates possible via `nix flake update` (FR-014).

---

## Phase 4: User Story 2 — Declarative Dotfile Management (Priority: P2)

**Goal**: Manage git, zsh, tmux, SSH, and AWS CLI configuration declaratively via Home Manager so the entire development environment is reproducible from a single repository.

**Independent Test**: After `sudo nixos-rebuild switch`, verify `~/.config/git/config`, `~/.zshrc`, `~/.config/tmux/tmux.conf`, `~/.ssh/config`, and `~/.aws/config` exist as symlinks to `/nix/store/...` with correct content.

### Implementation for User Story 2

- [ ] T012 [US2] Create `home.nix` at repository root with Home Manager boilerplate: `home.username = "todd"`, `home.homeDirectory = "/home/todd"`, `home.stateVersion = "24.05"`, `programs.home-manager.enable = true`
- [ ] T013 [US2] Add Home Manager NixOS module integration to `flake.nix`: add `home-manager.nixosModules.home-manager` to modules list with `useGlobalPkgs = true`, `useUserPackages = true`, `backupFileExtension = "hm-backup"`, `home-manager.users.todd = import ./home.nix` in `flake.nix`
- [ ] T014 [US2] Add `programs.git` config to `home.nix`: `userName = "Todd Costella"`, `userEmail = "ToddCostella@gmail.com"`, `extraConfig.init.defaultBranch = "main"` — git signing added in US4
- [ ] T015 [P] [US2] Remove system-level `programs.git` block (lines 507-516) from `configuration.nix` — moved to home.nix
- [ ] T016 [US2] Add `programs.zsh` config to `home.nix`: `enable = true`, `oh-my-zsh = { enable = true; plugins = [ "git" "docker" "docker-compose" "aws" "vi-mode" "fzf" ]; theme = "robbyrussell"; }`
- [ ] T017 [P] [US2] Remove system-level `programs.zsh.ohMyZsh` block (lines 491-495) from `configuration.nix` — keep `programs.zsh.enable = true` on line 490 for /etc/shells registration
- [ ] T018 [P] [US2] Remove `oh-my-zsh` package from `environment.systemPackages` (line 215) in `configuration.nix`
- [ ] T019 [US2] Add `programs.tmux` config to `home.nix`: migrate all settings from `remote-terminal.nix` (keyMode, baseIndex, escapeTime, historyLimit, clock24, newSession, terminal, plugins with catppuccin FIRST, extraConfig with prefix/mouse/keybindings)
- [ ] T020 [P] [US2] Remove `programs.tmux` block (lines 8-92) from `remote-terminal.nix` — keep `programs.mosh` and `services.openssh` blocks
- [ ] T021 [US2] Add `programs.ssh` config to `home.nix`: `enable = true`, `extraConfig` with `Host *` and `IdentityAgent ~/.1password/agent.sock` for 1Password SSH agent
- [ ] T022 [US2] Add `programs.awscli` config to `home.nix`: `enable = true`, profile settings with region/output per profile, `credential_process` entries referencing `op --cache inject --in-file ~/.aws/1pw/<profile>.json`
- [ ] T023 [US2] Add `home.file` entries to `home.nix` for AWS 1Password credential templates: `.aws/1pw/default.json` with `{{ op://vault/item/field }}` placeholders for AccessKeyId and SecretAccessKey
- [ ] T024 [US2] Migrate user-facing packages from `environment.systemPackages` to `home.packages` in `home.nix`: neovim (as package, NOT programs.neovim), htop, lazygit, lazydocker, bat, ripgrep, fd, jq, yq-go, httpie, fzf, yazi, zoxide, atuin, tree, gh, slack, obsidian, signal-desktop, zoom-us, figma-linux, dbeaver-bin, bcompare, wezterm, aerc, hugo, dropbox, pinta, apostrophe, rainfrog
- [ ] T025 [P] [US2] Remove packages migrated in T024 from `environment.systemPackages` in `configuration.nix` — keep system-level packages: gcc, gnumake, pkg-config, fonts, network tools, virtualization tools, custom shell scripts, zsh, nodejs, yarn, aws-cdk, docker-compose, uv, browsers, pandoc, texlive, arduino-ide, mu, bazecor, bluez, librsvg, screenshot scripts, wl-clipboard, mitmproxy, satty, claude-code, playerctl, brightnessctl
- [ ] T026 [US2] Stage `home.nix`, run `git add home.nix`, and validate with `sudo nixos-rebuild dry-build`
- [ ] T027 [US2] Apply with `sudo nixos-rebuild switch` and verify all dotfiles are generated: check `~/.config/git/config`, `~/.zshrc`, `~/.config/tmux/tmux.conf`, `~/.ssh/config`, `~/.aws/config` exist as symlinks

**Checkpoint**: US2 complete — all 5 dotfile categories managed declaratively. Acceptance scenarios AS 2.1-2.6 satisfied. New dotfiles appear automatically on rebuild (FR-004, FR-013).

---

## Phase 5: User Story 3 — Secrets Managed Through 1Password (Priority: P3)

**Goal**: Ensure all sensitive values are sourced from 1Password at runtime, never stored in committed files, and the system handles missing authentication gracefully.

**Independent Test**: Inspect all committed `.nix` files and verify zero plaintext secrets. With 1Password authenticated, verify AWS `credential_process` resolves credentials. With 1Password locked, verify `nixos-rebuild switch` still succeeds and errors are clear.

### Implementation for User Story 3

- [ ] T028 [US3] Verify no plaintext secrets exist in any `.nix` file: audit `home.nix`, `configuration.nix`, and all committed files for API keys, passwords, or private key material — only `op://` URIs and socket paths are allowed
- [ ] T029 [US3] Verify graceful degradation: rebuild with 1Password locked/closed and confirm `sudo nixos-rebuild switch` succeeds (all secret references are runtime-only, not build-time)
- [ ] T030 [US3] Document the secret reference pattern in a comment block at the top of `home.nix`: explain how to add new secrets using `op://` URIs in `home.file` templates, `credential_process` for AWS, or `IdentityAgent` for SSH (FR-008)

**Checkpoint**: US3 complete — zero secrets in committed files (SC-004). Build succeeds without 1Password (SC-007). Adding new secrets requires only 2 lines (SC-005). Acceptance scenarios AS 3.1-3.4 satisfied.

---

## Phase 6: User Story 4 — SSH Key Management Through 1Password (Priority: P4)

**Goal**: SSH keys managed via 1Password SSH agent — no private keys on disk. Git commit signing uses 1Password-managed SSH keys.

**Independent Test**: Verify `~/.ssh/` contains no private key files. Run `SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l` to list 1Password keys. Create a signed git commit and verify signature.

### Implementation for User Story 4

- [ ] T031 [US4] Add git commit signing config to `programs.git` in `home.nix`: `signing.format = "ssh"`, `signing.signer = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}"`, `signing.key = "<SSH_PUBLIC_KEY>"` (public key from 1Password), `signing.signByDefault = true`
- [ ] T032 [US4] Add `"gpg \"ssh\"".allowedSignersFile = "~/.ssh/allowed_signers"` to `programs.git.extraConfig` in `home.nix`
- [ ] T033 [P] [US4] Add `home.file.".ssh/allowed_signers"` entry to `home.nix` with format: `ToddCostella@gmail.com <SSH_PUBLIC_KEY>`
- [ ] T034 [US4] Apply with `sudo nixos-rebuild switch` and verify: git commit signing works via 1Password (may require 1Password SSH agent enabled in GUI: Settings > Developer > Use the SSH agent)
- [ ] T035 [US4] Verify no private key files exist in `~/.ssh/` — only `config`, `known_hosts`, and `allowed_signers` should be present

**Checkpoint**: US4 complete — SSH auth and git signing via 1Password agent (SC-006). No private keys on disk. Acceptance scenarios AS 4.1-4.3 satisfied.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Cleanup, channel removal, and final validation across all user stories.

- [ ] T036 Remove NixOS channels: run `sudo nix-channel --remove nixos` and `nix-channel --remove nixos` (if user-level channel exists)
- [ ] T037 Add `nix.channel.enable = false` to `configuration.nix` and rebuild with `sudo nixos-rebuild switch`
- [ ] T038 Review and clean up `*.hm-backup` files in home directory — compare with declarative config, then remove backups
- [ ] T039 Final validation: verify all success criteria SC-001 through SC-009 are met
- [ ] T040 Commit all changes with descriptive message and push to remote

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — must complete before US2 (flake must work before adding Home Manager)
- **US2 (Phase 4)**: Depends on US1 — Home Manager requires working flake
- **US3 (Phase 5)**: Depends on US2 — secrets audit requires dotfiles to be in place
- **US4 (Phase 6)**: Depends on US2 — git signing config added to existing `programs.git` in home.nix
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational) → US1 (Flakes) → US2 (Dotfiles) → US3 (Secrets)
                                                                            ↘ US4 (SSH/Signing)
                                                                                     ↘ Phase 7 (Polish)
```

**Note**: US3 and US4 can run in parallel after US2, as they modify different sections of `home.nix`:
- US3 audits and documents existing secret patterns (read-only + comments)
- US4 adds git signing config (modifies `programs.git` block)

### Within Each User Story

- Configuration changes before validation
- `dry-build` before `switch`
- Verification after `switch`
- Commit after successful verification

### Parallel Opportunities

- **Phase 2**: T005 and T006 modify different sections of `configuration.nix` and can run in parallel
- **US2**: T015, T017, T018, T020, T025 remove config from existing files and can run in parallel (different files/sections)
- **US4**: T033 creates `allowed_signers` file entry, independent of T031/T032 git signing config
- **US3 and US4**: Can execute in parallel after US2 completes (different concerns)

---

## Parallel Example: User Story 2

```bash
# These removal tasks can run in parallel (different files/sections):
Task: "T015 — Remove programs.git block from configuration.nix"
Task: "T017 — Remove programs.zsh.ohMyZsh block from configuration.nix"
Task: "T018 — Remove oh-my-zsh from environment.systemPackages in configuration.nix"
Task: "T020 — Remove programs.tmux block from remote-terminal.nix"
Task: "T025 — Remove migrated packages from environment.systemPackages in configuration.nix"

# Then sequentially: validate and apply
Task: "T026 — Stage home.nix and run dry-build"
Task: "T027 — Apply and verify dotfiles"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T007)
3. Complete Phase 3: User Story 1 (T008-T011)
4. **STOP and VALIDATE**: System builds reproducibly via flake. All existing functionality preserved.
5. This is a safe stopping point — the system works exactly as before but with pinned dependencies.

### Incremental Delivery

1. Setup + Foundational → Flake infrastructure ready
2. Add US1 (Flakes) → Reproducible builds → Commit (MVP!)
3. Add US2 (Dotfiles) → Declarative dev environment → Commit
4. Add US3 + US4 (Secrets + SSH) → Full 1Password integration → Commit
5. Polish → Channel cleanup, final validation → Commit
6. Each phase adds value without breaking previous phases.

---

## Notes

- [P] tasks = different files or sections, no dependencies on each other
- [Story] label maps task to specific user story for traceability
- All validation uses `sudo nixos-rebuild dry-build` (syntax) then `sudo nixos-rebuild switch` (apply)
- Rollback available at any point: `sudo nixos-rebuild rollback` or `git checkout <commit>`
- `<SSH_PUBLIC_KEY>` placeholder in T031/T033 must be replaced with actual public key from 1Password before applying
- AWS profile names/regions in T022/T023 are placeholders — Todd must provide actual profile details
- Commit after each checkpoint to enable safe rollback points
