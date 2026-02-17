# Quickstart: Flakes + Home Manager + 1Password Migration

**Feature**: 002-nixos-homemanager-dotfiles
**Prerequisites**: NixOS 24.05 running, 1Password GUI installed, internet access

---

## Phase 1: Flakes Migration (No Home Manager Yet)

### Step 1.1: Create flake.nix

Create `flake.nix` at the repository root with nixpkgs (nixos-24.05) and home-manager (release-24.05) inputs. Initially, the flake only wraps the existing configuration.nix — no Home Manager module yet.

### Step 1.2: Stage files for flake evaluation

```bash
git add flake.nix
```

All `.nix` files must be tracked by git for flake evaluation. Existing files are already tracked.

### Step 1.3: Generate lockfile

```bash
nix flake lock
```

Creates `flake.lock` with pinned revisions. Stage it: `git add flake.lock`.

### Step 1.4: Validate

```bash
sudo nixos-rebuild dry-build
```

Must succeed with zero errors. If it fails, debug before proceeding.

### Step 1.5: Test build

```bash
sudo nixos-rebuild test
```

Activates the new configuration without making it the boot default. Verify all services are running.

### Step 1.6: Apply and reboot

```bash
sudo nixos-rebuild switch
sudo reboot
```

After reboot, verify: desktop environment loads, Docker runs, all packages available.

### Step 1.7: Commit

```bash
git add flake.nix flake.lock
git commit -m "Migrate to Nix flakes for reproducible builds"
```

---

## Phase 2: Configuration.nix Modifications

### Step 2.1: Update function signature

Add `inputs` to the function signature of `configuration.nix`:
```nix
{ config, pkgs, inputs, ... }:
```

### Step 2.2: Update nix.nixPath and registry

Replace channel-based NIX_PATH with flake input reference. Add flake registry.

### Step 2.3: Add 1Password module config

Add `programs._1password.enable` and `programs._1password-gui` with `polkitPolicyOwners`.
Remove `_1password-gui` from `environment.systemPackages`.

### Step 2.4: Disable GnuPG SSH support

Change `enableSSHSupport = true` to `enableSSHSupport = false`.

### Step 2.5: Remove git and Oh-My-Zsh system-level config

Remove `programs.git` block and `programs.zsh.ohMyZsh` block. Keep `programs.zsh.enable = true`.

### Step 2.6: Validate and apply

```bash
sudo nixos-rebuild dry-build && sudo nixos-rebuild switch
```

---

## Phase 3: Home Manager + Dotfiles

### Step 3.1: Create home.nix

Create `home.nix` with Home Manager config for user "todd": git, zsh, tmux, SSH, AWS CLI.

### Step 3.2: Update flake.nix to include Home Manager module

Add `home-manager.nixosModules.home-manager` and inline HM settings to flake.nix modules list.

### Step 3.3: Stage and validate

```bash
git add home.nix
sudo nixos-rebuild dry-build
```

### Step 3.4: Apply

```bash
sudo nixos-rebuild switch
```

Home Manager backs up conflicting dotfiles to `*.hm-backup` and creates new symlinked config files.

### Step 3.5: Verify dotfiles

```bash
ls -la ~/.zshrc ~/.config/git/config ~/.config/tmux/tmux.conf ~/.ssh/config ~/.aws/config
# All should be symlinks to /nix/store/...
```

---

## Phase 4: 1Password Integration

### Step 4.1: Enable SSH agent in 1Password GUI

Settings > Developer > "Use the SSH agent" > Enable.

### Step 4.2: Verify SSH agent

```bash
SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
```

Should list your 1Password SSH keys.

### Step 4.3: Test git commit signing

```bash
echo "test" > /tmp/test-sign
cd /tmp && git init test-repo && cd test-repo
git add . && git commit -m "test signing"
git log --show-signature
```

### Step 4.4: Test AWS credential resolution

```bash
aws sts get-caller-identity --profile <profile-name>
```

Should authenticate via 1Password (may prompt for biometric).

---

## Phase 5: Cleanup

### Step 5.1: Remove channels

```bash
sudo nix-channel --list           # Verify what exists
sudo nix-channel --remove nixos   # Remove system channel
nix-channel --list                # Check user channels
nix-channel --remove nixos        # Remove if present
```

### Step 5.2: Add channel disable to config

Add `nix.channel.enable = false` to `configuration.nix` and rebuild.

### Step 5.3: Clean up backup files

```bash
find ~ -name "*.hm-backup" -type f  # Review what was backed up
# Manually delete after confirming no needed customizations
```

### Step 5.4: Final commit

```bash
git add -A
git commit -m "Complete flakes + Home Manager + 1Password migration"
```

---

## Rollback

At any point, if something goes wrong:

```bash
# Revert to previous NixOS generation (from bootloader or):
sudo nixos-rebuild rollback

# Revert config changes:
git checkout <last-good-commit> -- configuration.nix home.nix flake.nix
sudo nixos-rebuild switch
```

---

## Dependency Update (Ongoing)

```bash
# Update all inputs:
nix flake update

# Update only nixpkgs:
nix flake update nixpkgs

# Review and apply:
sudo nixos-rebuild switch
git add flake.lock && git commit -m "Update flake inputs"
```
