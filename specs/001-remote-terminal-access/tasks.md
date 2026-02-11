# Tasks: Remote Terminal Access from iOS

**Input**: Design documents from `/specs/001-remote-terminal-access/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Not requested in the feature specification. Manual verification steps are included at checkpoints per quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **NixOS module**: `remote-terminal.nix` at repository root
- **Main config**: `configuration.nix` at repository root
- **User config**: `~/.wezterm.lua` (not NixOS-managed, documented in quickstart)

---

## Phase 1: Setup

**Purpose**: Create the new NixOS module file and wire it into configuration.nix

- [x] T001 Create `remote-terminal.nix` at repository root with Nix module boilerplate (`{ config, pkgs, ... }:` header, empty body)
- [x] T002 Add `./remote-terminal.nix` to the imports list in `configuration.nix` (after `./playwright-dev.nix`)
- [x] T003 Remove `services.openssh.enable = true;` from `configuration.nix` (line 540 — will be moved to the new module)
- [x] T004 Validate syntax with `sudo nixos-rebuild dry-build`

**Checkpoint**: Module file exists, is imported, and config builds without errors. No functional changes yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Configure tmux with all keybindings, theme, and plugins — the core infrastructure all user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Add `programs.tmux` base options to `remote-terminal.nix`: `enable = true`, `keyMode = "vi"`, `baseIndex = 1`, `escapeTime = 0`, `historyLimit = 50000`, `clock24 = true`, `newSession = true`, `terminal = "tmux-256color"`, `customPaneNavigationAndResize = true`
- [x] T006 Add `programs.tmux.plugins` to `remote-terminal.nix`: `sensible`, `yank`, `resurrect`, `continuum`, and `tokyo-night-tmux` (with `extraConfig` for night variant and continuum auto-restore)
- [x] T007 Add `programs.tmux.extraConfig` to `remote-terminal.nix` with prefix override (`set -g prefix M-a; unbind C-b; bind M-a send-prefix`), true color override (`set -ag terminal-overrides ",xterm-256color:RGB"`), and mouse support (`set -g mouse on`)
- [x] T008 Add window-switching keybindings to `extraConfig` in `remote-terminal.nix`: `bind -n M-1 select-window -t 1` through `bind -n M-9 select-window -t 9`, and `bind c new-window -c "#{pane_current_path}"`
- [x] T009 Add pane-splitting keybindings to `extraConfig` in `remote-terminal.nix`: `bind | split-window -h -c "#{pane_current_path}"`, `bind - split-window -v -c "#{pane_current_path}"`, unbind default `"` and `%`
- [x] T010 Add Alt-arrow pane navigation to `extraConfig` in `remote-terminal.nix`: `bind -n M-Left select-pane -L`, `bind -n M-Right select-pane -R`, `bind -n M-Up select-pane -U`, `bind -n M-Down select-pane -D`
- [x] T011 Add vi copy-mode clipboard integration to `extraConfig` in `remote-terminal.nix`: `bind -T copy-mode-vi v send-keys -X begin-selection`, `bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"`
- [x] T012 Add `services.openssh` block to `remote-terminal.nix`: `enable = true`, `settings.PasswordAuthentication = false`, `settings.KbdInteractiveAuthentication = false`, `settings.PermitRootLogin = "no"`, `settings.AllowUsers = [ "todd" ]`
- [x] T013 Validate syntax with `sudo nixos-rebuild dry-build`

**Checkpoint**: Foundation ready. `dry-build` passes. tmux, SSH hardening, and all keybindings are configured. Ready for user story implementation.

---

## Phase 3: User Story 1 — Connect to Desktop Terminals from iPad (Priority: P1) MVP

**Goal**: Todd can SSH into the NixOS desktop from an iOS terminal app and attach to persistent tmux sessions

**Independent Test**: From an iOS device on the local network, SSH into the desktop, run `tmux attach -t main`, execute a command, disconnect, reconnect, and verify the session persisted

### Implementation for User Story 1

- [ ] T014 [US1] Apply configuration with `sudo nixos-rebuild switch`
- [ ] T015 [US1] Verify tmux is installed: run `tmux -V` and confirm output
- [ ] T016 [US1] Verify SSH hardening: run `sshd -T | grep passwordauthentication` and confirm `no`
- [ ] T017 [US1] Verify tmux session persistence: run `tmux new-session -As main`, create a file in the session, detach with `Alt-a d`, run `tmux attach -t main`, and confirm the file and session state are intact
- [ ] T018 [US1] Verify keybindings work: test `Alt+1`..`Alt+3` for window switching, `Alt-a |` and `Alt-a -` for splits, `Alt+Arrow` for pane navigation
- [ ] T019 [US1] Verify tokyo-night-tmux theme is active: confirm status bar renders with theme colors
- [ ] T020 [US1] Test remote SSH access: from iOS device, run `ssh todd@<desktop-ip>`, then `tmux attach -t main`, execute a command, and verify output
- [ ] T021 [US1] Test session persistence across disconnect: disconnect the iOS SSH session, reconnect, run `tmux attach -t main`, and verify the session is unchanged

**Checkpoint**: User Story 1 complete. Todd can connect from an iOS device via SSH, attach to persistent tmux sessions, and sessions survive disconnection.

---

## Phase 4: User Story 2 — Survive Network Interruptions (Priority: P2)

**Goal**: Connection from iOS survives WiFi drops, network switches, and sleep/wake cycles via Mosh

**Independent Test**: Connect from iOS via Mosh, toggle airplane mode for 10 seconds, toggle off, and verify the session resumes without manual reconnection

### Implementation for User Story 2

- [x] T022 [US2] Add `programs.mosh.enable = true;` to `remote-terminal.nix`
- [x] T023 [US2] Validate syntax with `sudo nixos-rebuild dry-build`
- [ ] T024 [US2] Apply configuration with `sudo nixos-rebuild switch`
- [ ] T025 [US2] Verify mosh-server is installed: run `which mosh-server` and confirm path
- [ ] T026 [US2] Verify Mosh firewall rules: run `sudo nft list ruleset | grep 60000` and confirm UDP 60000-61000 is open
- [ ] T027 [US2] Test Mosh connection: from iOS device, run `mosh todd@<desktop-ip>`, then `tmux attach -t main`, and verify interactive session
- [ ] T028 [US2] Test network resilience: while connected via Mosh from iOS, toggle airplane mode on for 10 seconds, toggle off, and verify session resumes automatically

**Checkpoint**: User Story 2 complete. Mosh provides resilient connections that survive network interruptions.

---

## Phase 5: User Story 3 — Use the Same Terminal Layout on Desktop and Remotely (Priority: P3)

**Goal**: WezTerm on the desktop auto-attaches to the same tmux sessions accessed remotely from iOS

**Independent Test**: Create a tmux session on the desktop, verify it is visible from WezTerm locally, connect from iOS and confirm the same session is accessible with both clients attached simultaneously

### Implementation for User Story 3

- [ ] T029 [US3] Update `~/.wezterm.lua` to set `default_prog = { '/run/current-system/sw/bin/tmux', 'new-session', '-As', 'main' }` and `enable_tab_bar = false`
- [ ] T030 [US3] Restart WezTerm and verify it opens directly into a tmux session named "main"
- [ ] T031 [US3] Test simultaneous access: with WezTerm attached to the "main" session on the desktop, connect from iOS via Mosh and run `tmux attach -t main`, then verify both clients see the same windows
- [ ] T032 [US3] Test cross-device visibility: create a new tmux window from the iOS device (`Alt-a c`), switch to it on the desktop (`Alt+2`), and verify it appears on both clients

**Checkpoint**: All user stories complete. Desktop WezTerm and iOS Mosh clients share the same persistent tmux sessions simultaneously.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation

- [ ] T033 Run full quickstart.md walkthrough end-to-end per `specs/001-remote-terminal-access/quickstart.md`
- [ ] T034 Verify all success criteria from spec.md: SC-001 (<10s connect), SC-002 (session persistence), SC-003 (network resilience), SC-004 (simultaneous access), SC-005 (single `nixos-rebuild switch`)
- [ ] T035 Commit all changes to git with descriptive message

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 — delivers SSH + tmux (MVP)
- **User Story 2 (Phase 4)**: Depends on Phase 3 — adds Mosh on top of working SSH + tmux
- **User Story 3 (Phase 5)**: Depends on Phase 3 — adds WezTerm integration (can run in parallel with Phase 4)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Foundational only. No other story dependencies.
- **User Story 2 (P2)**: Depends on US1 (needs working SSH + tmux to layer Mosh on top)
- **User Story 3 (P3)**: Depends on US1 (needs working tmux sessions to attach WezTerm to). Independent of US2.

### Parallel Opportunities

- **Phase 2**: T005-T012 all modify `remote-terminal.nix` — execute sequentially
- **Phase 4 + Phase 5**: US2 (Mosh) and US3 (WezTerm integration) can run in parallel after US1 is complete, as they modify different files (`remote-terminal.nix` vs `~/.wezterm.lua`)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T013)
3. Complete Phase 3: User Story 1 (T014-T021)
4. **STOP and VALIDATE**: SSH into desktop from iOS, attach to tmux, verify persistence
5. Working remote access is usable now (plain SSH, no Mosh resilience yet)

### Incremental Delivery

1. Setup + Foundational → Module built and config builds
2. User Story 1 → SSH + tmux working from iOS (MVP)
3. User Story 2 → Add Mosh for network resilience
4. User Story 3 → WezTerm auto-attaches to shared tmux sessions
5. Polish → End-to-end validation

---

## Notes

- All NixOS config tasks modify files at repository root (`remote-terminal.nix`, `configuration.nix`)
- WezTerm config (`~/.wezterm.lua`) is a user dotfile, not NixOS-managed
- Verification tasks (T015-T021, T025-T028, T030-T032) require the config to be applied first
- `dry-build` validation tasks (T004, T013, T023) catch syntax errors before applying
- `nixos-rebuild switch` tasks (T014, T024) are the actual deployment steps
