# Contract: flake.nix

**File**: `/etc/nixos/flake.nix` (NEW)
**Requirement**: FR-001, FR-002, FR-009, FR-014

## Structure

```nix
{
  description = "NixOS system configuration for nixos-dev";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.nixos-dev = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.todd = import ./home.nix;
        }
      ];
    };
  };
}
```

## Constraints

1. `nixosConfigurations` key MUST be `nixos-dev` (matches `networking.hostName`)
2. `home-manager.inputs.nixpkgs.follows` MUST be `"nixpkgs"` (prevents double nixpkgs evaluation)
3. `specialArgs` MUST pass `inputs` (needed by configuration.nix for nix.nixPath and nix.registry)
4. `useGlobalPkgs = true` MUST be set (shares system pkgs including allowUnfree)
5. `useUserPackages = true` MUST be set (installs to /etc/profiles/per-user/todd)
6. `backupFileExtension` MUST be set for first activation (backs up conflicting dotfiles)
7. The file MUST be `git add`-ed before any `nixos-rebuild` command

## Generated Artifact

- `flake.lock` — auto-generated on first evaluation, committed to git
