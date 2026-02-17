# Data Model: Flakes + Home Manager + 1Password Configuration

**Feature**: 002-nixos-homemanager-dotfiles
**Date**: 2026-02-17

This feature does not have a traditional data model (no database, no API entities). Instead, the "entities" are NixOS configuration files and the relationships between them. This document maps the configuration entity graph.

---

## Configuration Entity Graph

```text
flake.nix (NEW)
  ├── inputs: nixpkgs (nixos-24.05), home-manager (release-24.05)
  ├── outputs: nixosConfigurations.nixos-dev
  │     ├── imports: configuration.nix (MODIFIED)
  │     ├── module: home-manager.nixosModules.home-manager
  │     └── inline: home-manager settings (useGlobalPkgs, useUserPackages, backupFileExtension)
  │           └── home-manager.users.todd → home.nix (NEW)
  └── generates: flake.lock (NEW, auto-generated)

configuration.nix (MODIFIED)
  ├── imports: [unchanged module list]
  ├── function signature: { config, pkgs, inputs, ... }  ← adds 'inputs' via specialArgs
  ├── REMOVES: programs.zsh.ohMyZsh block (moved to home.nix)
  ├── REMOVES: programs.git block (moved to home.nix)
  ├── REMOVES: _1password-gui from environment.systemPackages
  ├── ADDS: programs._1password.enable = true
  ├── ADDS: programs._1password-gui = { enable = true; polkitPolicyOwners = ["todd"]; }
  ├── MODIFIES: programs.gnupg.agent.enableSSHSupport = false (was true)
  ├── MODIFIES: nix.nixPath → uses inputs.nixpkgs
  ├── ADDS: nix.registry.nixpkgs.flake = inputs.nixpkgs
  └── ADDS: nix.channel.enable = false (after verified migration)

home.nix (NEW)
  ├── home.username = "todd"
  ├── home.homeDirectory = "/home/todd"
  ├── home.stateVersion = "24.05"
  ├── programs.home-manager.enable = true
  │
  ├── programs.git
  │     ├── userName, userEmail, init.defaultBranch
  │     ├── signing: format=ssh, signer=op-ssh-sign, key=<public-key>, signByDefault=true
  │     └── settings: gpg.ssh.allowedSignersFile
  │
  ├── programs.zsh
  │     ├── enable = true
  │     ├── oh-my-zsh: plugins=[git,docker,docker-compose,aws,vi-mode,fzf], theme=robbyrussell
  │     └── additional shell integrations (fzf, zoxide, atuin, direnv hooks)
  │
  ├── programs.tmux
  │     ├── enable = true
  │     ├── plugins: [catppuccin, resurrect, continuum, sensible, yank]
  │     └── settings: prefix, mouse, etc. (migrated from remote-terminal.nix)
  │
  ├── programs.ssh
  │     ├── enable = true
  │     ├── matchBlocks: host entries (non-sensitive)
  │     └── extraConfig: IdentityAgent ~/.1password/agent.sock
  │
  ├── programs.awscli
  │     ├── enable = true
  │     ├── settings: profile blocks with region, output
  │     └── credentials: credential_process per profile → op inject
  │
  ├── home.file
  │     ├── ".aws/1pw/<profile>.json" — op:// template files per AWS profile
  │     └── ".ssh/allowed_signers" — public key for signature verification
  │
  └── home.packages: [user-facing dev tools migrated from environment.systemPackages]

remote-terminal.nix (MODIFIED)
  ├── REMOVES: programs.tmux block (moved to home.nix)
  └── KEEPS: programs.mosh, services.openssh (unchanged)
```

---

## Entity Relationships

| Source Entity | Target Entity | Relationship | Notes |
|---------------|---------------|--------------|-------|
| `flake.nix` | `nixpkgs` | input (pinned in flake.lock) | nixos-24.05 branch |
| `flake.nix` | `home-manager` | input (follows nixpkgs) | release-24.05 branch |
| `flake.nix` | `configuration.nix` | imports | Existing file, modified |
| `flake.nix` | `home.nix` | references via `home-manager.users.todd` | New file |
| `configuration.nix` | `inputs.nixpkgs` | uses via specialArgs | For nix.nixPath and nix.registry |
| `configuration.nix` | `programs._1password*` | enables NixOS modules | Replaces raw package in systemPackages |
| `home.nix` | `pkgs._1password-gui` | references `op-ssh-sign` binary | For git signing.signer |
| `home.nix` | `~/.1password/agent.sock` | references socket path (string) | Runtime dependency on 1Password GUI |
| `home.nix` | `op` CLI | references in credential_process | Runtime dependency on 1Password CLI |
| `home.nix` | AWS 1pw template files | manages via home.file | Contains op:// URIs (safe to commit) |

---

## State Transitions

### Migration State Machine

```text
[Current State]              [Intermediate]              [Final State]
Channel-based config    →    Flakes (no HM)         →    Flakes + Home Manager + 1Password
configuration.nix only       + flake.nix                  + flake.nix
                             + flake.lock                 + flake.lock
                             (verify boot)                + home.nix
                                                          + modified configuration.nix
                                                          + modified remote-terminal.nix
```

The migration MUST go through the intermediate state (flakes without Home Manager) to verify the flake build works before adding Home Manager complexity. This is enforced in the task ordering.

---

## Validation Rules

| Rule | Entity | Constraint |
|------|--------|------------|
| No secrets in Nix store | All `.nix` files | No `op read`, `op inject` executed at evaluation/build time |
| Version match | flake.nix inputs | nixpkgs branch and home-manager branch must both be 24.05 |
| Git tracked | All `.nix` files | Must be `git add`-ed before `nixos-rebuild` in flake mode |
| Hostname match | flake.nix outputs key | Must match `networking.hostName` ("nixos-dev") |
| Home stateVersion | home.nix | Must be "24.05" |
| Plugin order | home.nix tmux | Catppuccin before resurrect/continuum |
| No enableSSHSupport | configuration.nix | GnuPG SSH must be disabled when 1Password SSH agent is configured |
| No duplicate zsh config | configuration.nix + home.nix | Oh-My-Zsh in exactly one place (home.nix) |
| No duplicate git config | configuration.nix + home.nix | Git settings in exactly one place (home.nix) |
