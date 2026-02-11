# NixOS Module Contract: remote-terminal.nix

**Date**: 2026-02-11

## Overview

This feature is a NixOS system configuration module, not a
web service. There are no API endpoints. The "contract" is the
set of NixOS options, system services, and firewall rules the
module configures.

## Module: `remote-terminal.nix`

### Inputs (NixOS options set by the module)

| NixOS Option                               | Value                    |
|--------------------------------------------|--------------------------|
| `programs.tmux.enable`                     | `true`                   |
| `programs.tmux.extraConfig` (prefix)       | `M-a` (Alt-a prefix)    |
| `programs.tmux.keyMode`                    | `"vi"`                   |
| `programs.tmux.baseIndex`                  | `1`                      |
| `programs.tmux.escapeTime`                 | `0`                      |
| `programs.tmux.historyLimit`               | `50000`                  |
| `programs.tmux.clock24`                    | `true`                   |
| `programs.tmux.newSession`                 | `true`                   |
| `programs.tmux.terminal`                   | `"tmux-256color"`        |
| `programs.tmux.plugins`                    | sensible, yank, resurrect, continuum, tokyo-night-tmux |
| `programs.tmux.customPaneNavigationAndResize` | `true`                |
| `programs.tmux.extraConfig`                | Mouse, Alt+number window switching, splits, clipboard, styling |
| `programs.mosh.enable`                     | `true`                   |

### Outputs (system effects)

| Effect                          | Description                              |
|---------------------------------|------------------------------------------|
| `/etc/tmux.conf`                | Generated tmux configuration file        |
| `tmux` binary in system PATH    | Available to all users                   |
| `mosh-server` binary            | Available for incoming Mosh connections  |
| UDP 60000-61000 firewall open   | Mosh port range (auto via `programs.mosh`) |

### Dependencies (existing config, not modified by module)

| Existing Config                      | Required State        |
|--------------------------------------|-----------------------|
| `services.openssh.enable`            | `true` (already set)  |
| `wl-clipboard` in system packages    | Present (for tmux yank) |

### SSH Hardening (applied to existing service)

| Setting                              | Value                 |
|--------------------------------------|-----------------------|
| `settings.PasswordAuthentication`    | `false`               |
| `settings.KbdInteractiveAuthentication` | `false`            |
| `settings.PermitRootLogin`           | `"no"`                |
| `settings.AllowUsers`                | `[ "todd" ]`          |

## Import Contract

The module MUST be importable via:

```nix
imports = [
  ./remote-terminal.nix
];
```

It MUST NOT conflict with existing `services.openssh.enable`
or other modules in `configuration.nix`.

## Verification

After `sudo nixos-rebuild switch`:

1. `tmux -V` returns a version string
2. `which mosh-server` returns a path
3. `ss -ulnp | grep 60000` shows no listener (Mosh starts
   on-demand per connection, but firewall rules are present)
4. `sudo iptables -L -n | grep 60000` or
   `sudo nft list ruleset | grep 60000` shows UDP range open
5. `sshd -T | grep passwordauthentication` returns `no`
6. `tmux new-session -As test` creates/attaches a session
