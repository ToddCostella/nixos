# Quickstart: Remote Terminal Access from iOS

**Date**: 2026-02-11
**Branch**: `001-remote-terminal-access`

## Prerequisites

- NixOS desktop with this configuration repo checked out
- iPhone or iPad with a Mosh-capable terminal app (e.g.,
  Blink Shell)
- Both devices on the same local network
- SSH key pair generated on the iOS device

## Step 1: Apply NixOS Configuration

```bash
cd /path/to/nixos-config
sudo nixos-rebuild dry-build   # Validate first
sudo nixos-rebuild switch      # Apply
```

This installs and configures tmux, mosh, and hardens SSH.

## Step 2: Verify Services

```bash
# tmux is available
tmux -V

# mosh-server is available
which mosh-server

# SSH is running and key-only
systemctl status sshd
sshd -T | grep passwordauthentication
# Expected output: passwordauthentication no
```

## Step 3: Configure SSH Key on iOS Device

On your iPhone/iPad (in Blink Shell or your chosen app):

1. Generate an SSH key pair if you don't have one
2. Copy the public key to the NixOS desktop:
   ```bash
   # On NixOS desktop, add the iOS public key:
   mkdir -p ~/.ssh
   echo "ssh-ed25519 AAAA... ios-device" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```
   Or add the key to `users.users.todd.openssh.authorizedKeys.keys`
   in the NixOS config for a declarative approach.

## Step 4: Configure WezTerm (Desktop)

Add to `~/.wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.default_prog = {
  '/run/current-system/sw/bin/tmux',
  'new-session', '-As', 'main'
}
config.enable_tab_bar = false

return config
```

Restart WezTerm. It now opens directly into a tmux session
named "main".

## Step 5: Connect from iOS

In Blink Shell (or your terminal app):

```bash
mosh todd@nixos-dev.local
# Or use the desktop's LAN IP:
mosh todd@192.168.x.x
```

Once connected:

```bash
tmux attach -t main
```

You are now viewing the same session as your desktop WezTerm.

## Step 6: Verify Multi-Device Access

1. On the desktop (WezTerm), create a new tmux window:
   `Alt-a c`
2. On the iOS device, switch to the new window:
   `Alt-a n`
3. Verify both clients see the same windows and panes

## Day-to-Day Usage

| Task                    | Command                           |
|-------------------------|-----------------------------------|
| Open terminal (desktop) | Launch WezTerm (auto-attaches)    |
| Connect (iOS)           | `mosh todd@nixos-dev.local`       |
| Attach to session       | `tmux attach -t main`             |
| Split pane vertically   | `Alt-a |`                        |
| Split pane horizontally | `Alt-a -`                        |
| Navigate panes          | `Alt-Arrow` or `Alt-a h/j/k/l`  |
| New window              | `Alt-a c`                        |
| Next/prev window        | `Alt-a n` / `Alt-a p`          |
| Zoom pane (fullscreen)  | `Alt-a z`                        |
| Detach (keep running)   | `Alt-a d`                        |
| List sessions           | `tmux ls`                         |

## Troubleshooting

**Mosh connection refused**: Check that UDP 60000-61000 is
open: `sudo nft list ruleset | grep 60000`

**SSH key rejected**: Verify the public key is in
`~/.ssh/authorized_keys` and permissions are correct
(`chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/authorized_keys`).

**tmux session not found**: Run `tmux ls` to list sessions.
If none exist, `tmux new-session -s main` creates one.

**WezTerm not attaching to tmux**: Check that `default_prog`
path is correct: `ls -la /run/current-system/sw/bin/tmux`
