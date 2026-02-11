# Research: Remote Terminal Access from iOS

**Date**: 2026-02-11
**Branch**: `001-remote-terminal-access`

## R1: Terminal Multiplexer Choice

**Decision**: tmux

**Rationale**: tmux is the only multiplexer that enables the
core requirement — accessing the same persistent sessions from
both WezTerm on the desktop and an iOS SSH client. WezTerm's
built-in multiplexer (SSHMUX domain) requires WezTerm on both
ends; no WezTerm client exists for iOS. tmux sessions are
server-side and accessible from any terminal.

**Alternatives considered**:
- WezTerm SSHMUX domain: No iOS client; ruled out.
- GNU Screen: Legacy; fewer features, weaker plugin ecosystem,
  no meaningful advantage over tmux for this use case.
- Zellij: Newer, less mature ecosystem; fewer iOS client
  compatibility guarantees; tmux has broader community support.

## R2: Remote Transport Protocol

**Decision**: Mosh (Mobile Shell) over SSH

**Rationale**: Mosh uses UDP with the State Synchronization
Protocol to survive network roaming, sleep/wake cycles, and
WiFi switches — exactly the failure modes iOS devices encounter.
It provides local echo prediction for responsive input on any
latency. tmux handles session persistence; Mosh handles
connection resilience.

**Alternatives considered**:
- Plain SSH: Drops on network change. No local echo prediction.
  Would require manual reconnect + `tmux attach` each time.
- Eternal Terminal (ET): Auto-reconnects over TCP, native
  scrollback. But no iOS client — Blink Shell supports Mosh
  natively but not ET. ET would connect via plain SSH from iOS,
  negating its advantage. Mosh has superior iOS ecosystem.

## R3: iOS Terminal Client

**Decision**: Recommend Blink Shell (user purchase, not NixOS config)

**Rationale**: Blink Shell has native Mosh support, hardware
keyboard integration, and active development. It is the
consensus recommendation for power users connecting to remote
tmux sessions from iOS.

**Alternatives considered**:
- Termius: Mosh support, cross-platform sync. Subscription
  model; less focused on power-user workflows.
- Prompt (Panic): No Mosh support; SSH only. Would lose the
  connection resilience from US2.

## R4: NixOS tmux Module

**Decision**: Use `programs.tmux` NixOS module

**Rationale**: NixOS provides a first-class `programs.tmux`
module with options for prefix key, vi mode, plugins, base
index, and `extraConfig` for custom settings. Configuration
is fully declarative and generates `/etc/tmux.conf`.

**Key configuration choices**:
- Prefix: `Alt-a` (set via extraConfig as `M-a`; the NixOS
  `shortcut` option only supports Ctrl combos)
- Vi key mode with mouse support enabled
- `tmux-256color` terminal with RGB override for true color
- Plugins: sensible, yank (clipboard), resurrect + continuum
  (session save/restore across reboots), tokyo-night-tmux
  (theme — available in nixpkgs as `tmuxPlugins.tokyo-night-tmux`)
- `newSession = true` so `tmux attach` auto-creates if needed
- Window switching: `Alt+number` (no prefix) to match existing
  WezTerm `Alt+number` tab navigation habit
- New window: `Ctrl-a c` (keeps current path)
- Pane splitting: `|` for vertical, `-` for horizontal
  (keeping current path)
- Clipboard integration: `wl-copy` for Wayland

## R5: NixOS Mosh Module

**Decision**: Use `programs.mosh` NixOS module

**Rationale**: NixOS provides `programs.mosh` which installs
the package and opens UDP 60000-61000 in the firewall
automatically (`openFirewall = true` by default). Single line
of config.

## R6: OpenSSH Hardening

**Decision**: Harden existing `services.openssh` config

**Rationale**: SSH is already enabled. Need to disable password
auth (key-only), restrict to user `todd`, and disable root
login. Not binding to a specific LAN IP to avoid boot-order
issues with NetworkManager; instead rely on router firewall
for WAN blocking (local-network-only scope per spec).

## R7: WezTerm + tmux Integration

**Decision**: Configure WezTerm `default_prog` to auto-attach
to a tmux session named "main"

**Rationale**: `tmux new-session -As main` creates the session
if it doesn't exist, or attaches if it does. Setting this as
WezTerm's `default_prog` means opening WezTerm = opening tmux.
Disable WezTerm's tab bar since tmux provides its own.

**Implementation**: Lua config in `~/.wezterm.lua` or managed
via NixOS home-manager (or documented in quickstart as a manual
user config step, since this repo manages system config, not
user dotfiles).

## R8: Session Persistence Across Reboots

**Decision**: Use tmux-resurrect + tmux-continuum plugins

**Rationale**: The spec accepts that reboots lose sessions
(expected behavior). However, tmux-resurrect can save and
restore window/pane layouts and running programs.
tmux-continuum auto-saves every 15 minutes and auto-restores
on tmux server start. This is a quality-of-life enhancement,
not a hard requirement.
