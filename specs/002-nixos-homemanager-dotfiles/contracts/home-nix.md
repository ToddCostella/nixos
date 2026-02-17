# Contract: home.nix

**File**: `/etc/nixos/home.nix` (NEW)
**Requirement**: FR-004, FR-005, FR-006, FR-007, FR-013, FR-015

## Structure

```nix
{ config, pkgs, lib, ... }:
{
  home.username = "todd";
  home.homeDirectory = "/home/todd";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;

  # --- Git (FR-004, FR-007) ---
  programs.git = {
    enable = true;
    userName = "Todd Costella";
    userEmail = "ToddCostella@gmail.com";
    signing = {
      format = "ssh";
      signer = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
      key = "<SSH_PUBLIC_KEY_FROM_1PASSWORD>";  # e.g., "ssh-ed25519 AAAA..."
      signByDefault = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      "gpg \"ssh\"".allowedSignersFile = "~/.ssh/allowed_signers";
    };
  };

  # --- Zsh + Oh-My-Zsh (FR-004) ---
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "docker-compose" "aws" "vi-mode" "fzf" ];
      theme = "robbyrussell";
    };
    # Shell tool integrations added here (initExtra or enableCompletion)
  };

  # --- Tmux (FR-004) ---
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      { plugin = catppuccin; extraConfig = "..."; }  # MUST be first
      sensible
      yank
      resurrect
      continuum
    ];
    # Settings migrated from remote-terminal.nix
  };

  # --- SSH (FR-004, FR-006) ---
  programs.ssh = {
    enable = true;
    matchBlocks = {
      # Host entries (non-sensitive only)
    };
    extraConfig = ''
      Host *
          IdentityAgent ~/.1password/agent.sock
    '';
  };

  # --- AWS CLI (FR-004, FR-015) ---
  programs.awscli = {
    enable = true;
    settings = {
      "default" = {
        region = "<default-region>";
        output = "json";
      };
      "profile <name>" = {
        region = "<region>";
        output = "json";
      };
    };
    credentials = {
      "default" = {
        credential_process = "op --cache inject --in-file ~/.aws/1pw/default.json";
      };
      "<name>" = {
        credential_process = "op --cache inject --in-file ~/.aws/1pw/<name>.json";
      };
    };
  };

  # --- 1Password Credential Templates (FR-005, FR-008) ---
  home.file = {
    ".aws/1pw/default.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://vault/item/access_key_id }}";
      SecretAccessKey = "{{ op://vault/item/secret_access_key }}";
    };
    ".ssh/allowed_signers".text = ''
      ToddCostella@gmail.com <SSH_PUBLIC_KEY>
    '';
  };

  # --- User Packages (FR-004) ---
  home.packages = with pkgs; [
    neovim    # Install only, do NOT use programs.neovim
    # ... user-facing dev tools migrated from environment.systemPackages
  ];
}
```

## Constraints

1. `home.stateVersion` MUST be `"24.05"`
2. `signing.signer` MUST use `lib.getExe'` to reference `op-ssh-sign` from `_1password-gui` (NOT `/opt/1Password/op-ssh-sign`)
3. `signing.key` MUST be the public key only (no private key material)
4. Oh-My-Zsh MUST NOT also be configured at system level in configuration.nix
5. Tmux plugins: catppuccin MUST be listed before resurrect/continuum
6. `IdentityAgent` MUST point to `~/.1password/agent.sock`
7. AWS credential templates contain only `op://` URIs (safe to commit)
8. Neovim MUST be in `home.packages`, NOT `programs.neovim` (avoids managing ~/.config/nvim/)
9. No `op read` or `op inject` calls at Nix evaluation time (all runtime)

## Generates

| Path | Content |
|------|---------|
| `~/.config/git/config` | Git configuration with signing |
| `~/.zshrc` | Zsh config with Oh-My-Zsh |
| `~/.config/tmux/tmux.conf` | Tmux config with plugins |
| `~/.ssh/config` | SSH client config with 1Password agent |
| `~/.aws/config` | AWS CLI profiles |
| `~/.aws/credentials` | AWS credential_process entries |
| `~/.aws/1pw/*.json` | 1Password inject templates |
| `~/.ssh/allowed_signers` | SSH signature verification |
