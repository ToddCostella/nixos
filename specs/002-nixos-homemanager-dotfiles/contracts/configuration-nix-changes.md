# Contract: configuration.nix Changes

**File**: `/etc/nixos/configuration.nix` (MODIFIED)
**Requirement**: FR-002, FR-003, FR-006, FR-013

## Changes Summary

### Function Signature
```nix
# BEFORE
{ config, pkgs, ... }:

# AFTER
{ config, pkgs, inputs, ... }:
```
`inputs` is passed via `specialArgs` in flake.nix.

### REMOVE: System-level Oh-My-Zsh config (lines 489-496)
```nix
# REMOVE this block (moved to home.nix)
programs.zsh.ohMyZsh = {
  enable = true;
  plugins = [ "git" "docker" "docker-compose" "aws" "vi-mode" "fzf" ];
  theme = "robbyrussell";
};
```
Keep `programs.zsh.enable = true` (registers zsh in /etc/shells).

### REMOVE: System-level Git config (lines 507-516)
```nix
# REMOVE this block (moved to home.nix)
programs.git = {
  enable = true;
  config = { ... };
};
```

### REMOVE: `oh-my-zsh` from environment.systemPackages (line 215)

### REMOVE: `_1password-gui` from environment.systemPackages (line 251)

### ADD: 1Password NixOS module config
```nix
programs._1password.enable = true;
programs._1password-gui = {
  enable = true;
  polkitPolicyOwners = [ "todd" ];
};
```

### MODIFY: GnuPG agent (lines 534-537)
```nix
# BEFORE
programs.gnupg.agent = {
  enable = true;
  enableSSHSupport = true;
};

# AFTER
programs.gnupg.agent = {
  enable = true;
  enableSSHSupport = false;  # 1Password SSH agent handles SSH keys
};
```

### MODIFY: nix.nixPath (lines 582-585)
```nix
# BEFORE
nix.nixPath = [
  "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs"
  "nixos-config=/etc/nixos/configuration.nix"
];

# AFTER
nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
```

### ADD: Flake registry
```nix
nix.registry.nixpkgs.flake = inputs.nixpkgs;
```

### ADD: Disable channels (after verified migration)
```nix
nix.channel.enable = false;
```

### MODIFY: Move user-facing packages to home.nix
Packages like `neovim`, `htop`, `lazygit`, `slack`, `obsidian`, etc. move from `environment.systemPackages` to `home.packages` in home.nix. System infrastructure packages (gcc, build tools, fonts, virtualization, network tools, custom scripts) remain.

## Constraints

1. `programs.zsh.enable = true` MUST remain (login shell registration)
2. `users.users.todd.shell = pkgs.zsh` MUST remain
3. All existing module imports MUST remain unchanged
4. `nixpkgs.config.allowUnfree = true` MUST remain (propagates to Home Manager via useGlobalPkgs)
5. `system.stateVersion = "24.05"` MUST NOT change
6. `nix.channel.enable = false` should only be added AFTER successful flake-based boot

## Unchanged Modules (FR-003)

These files MUST NOT be modified:
- `hardware-configuration.nix`
- `esp32-dev.nix`
- `photo-restoration.nix`
- `desktop-icons.nix`
- `desktop-gnome.nix`
- `desktop-cosmic.nix`
- `playwright-dev.nix`

## Modified Module

- `remote-terminal.nix` — tmux configuration block removed (moved to home.nix). Mosh and SSH server config remain.
