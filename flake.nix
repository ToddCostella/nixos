{
  description = "NixOS system configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop.url = "github:aaddrick/claude-desktop-debian";
    # herdr — terminal workspace manager for AI coding agents.
    # Ships only a package + overlay (no NixOS/home module). follows nixpkgs so it
    # builds against our pinned nixpkgs instead of pulling in a second one.
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, claude-desktop, herdr, ... }@inputs:
  let
    hmBase = {
      home-manager.useGlobalPkgs = false;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-backup";
    };
  in
  {
    nixosConfigurations.nixos-dev = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        { nixpkgs.overlays = [ claude-desktop.overlays.default ]; }
        ./modules/common.nix
        ./hosts/nixos-dev/configuration.nix
        home-manager.nixosModules.home-manager
        (hmBase // {
          home-manager.users.todd = {
            imports = [ ./home/todd-base.nix ./home/todd-desktop.nix ];
            nixpkgs.overlays = [ claude-desktop.overlays.default herdr.overlays.default ];
          };
        })
      ];
    };

    # Persistent libvirt/QEMU VM: same desktop + tools as nixos-dev, VM-adapted
    # hardware. Installed via ISO (see docs/vm-guest-install.md), managed in
    # virt-manager. Distinct from the throwaway `vm-test` build-vm below.
    nixosConfigurations.vm-guest = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        { nixpkgs.overlays = [ claude-desktop.overlays.default ]; }
        ./modules/common.nix
        ./hosts/vm-guest/configuration.nix
        home-manager.nixosModules.home-manager
        (hmBase // {
          home-manager.users.todd = {
            imports = [ ./home/todd-base.nix ./home/todd-desktop.nix ];
            nixpkgs.overlays = [ claude-desktop.overlays.default herdr.overlays.default ];
          };
        })
      ];
    };

    # Throwaway VM build of nixos-dev for `nixos-rebuild build-vm --flake .#vm-test`.
    # Identical to nixos-dev plus ./vm-test.nix (test password + GNOME autologin).
    # Not a real host; safe to remove along with vm-test.nix.
    nixosConfigurations.vm-test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        { nixpkgs.overlays = [ claude-desktop.overlays.default ]; }
        ./modules/common.nix
        ./hosts/nixos-dev/configuration.nix
        ./vm-test.nix
        home-manager.nixosModules.home-manager
        (hmBase // {
          home-manager.users.todd = {
            imports = [ ./home/todd-base.nix ./home/todd-desktop.nix ];
            nixpkgs.overlays = [ claude-desktop.overlays.default herdr.overlays.default ];
          };
        })
      ];
    };

    nixosConfigurations.home-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./modules/common.nix
        ./hosts/home-server/configuration.nix
        home-manager.nixosModules.home-manager
        (hmBase // {
          home-manager.users.todd = {
            imports = [ ./home/todd-base.nix ];
          };
        })
      ];
    };
  };
}
