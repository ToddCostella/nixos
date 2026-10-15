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
    # Catppuccin theme for COSMIC — plain asset repo (whiskers .tera templates +
    # pre-rendered theme RONs), no flake.nix, hence flake = false. Pinned here so
    # the template source is reproducible even though the final import into
    # COSMIC Settings -> Appearance is still a manual one-time click.
    catppuccin-cosmic = {
      url = "github:catppuccin/cosmic-desktop";
      flake = false;
    };
    # strata — keyboard-first GTK4 file manager. No upstream flake, so flake =
    # false (we read its source + Cargo.lock directly). Built from source by
    # pkgs/strata/default.nix and added to the desktop package set. Pinned to the
    # v1.0.0 stable tag; bump this ref to update.
    strata = {
      url = "github:lgse/strata/v1.0.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, claude-desktop, herdr, ... }@inputs:
  let
    # Shared home-manager wiring. Takes the todd user config and returns a full
    # NixOS module, so all the home-manager.* settings live in one place.
    #
    # This is a function rather than an attrset merged with `//` because `//` is
    # shallow: as separate dotted keys, a host's own `home-manager.users.todd`
    # would replace the whole `home-manager` attrset and silently drop
    # useUserPackages / backupFileExtension / extraSpecialArgs.
    hmFor = userCfg: {
      home-manager = {
        useGlobalPkgs = false;
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        # Home modules get `inputs` too, so they can reference pinned non-flake
        # asset repos (e.g. catppuccin-cosmic) the same way system modules do.
        extraSpecialArgs = { inherit inputs; };
        users.todd = userCfg;
      };
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
        (hmFor {
          imports = [ ./home/todd-base.nix ./home/todd-desktop.nix ];
          nixpkgs.overlays = [ claude-desktop.overlays.default herdr.overlays.default ];
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
        (hmFor {
          imports = [ ./home/todd-base.nix ./home/todd-desktop.nix ];
          nixpkgs.overlays = [ claude-desktop.overlays.default herdr.overlays.default ];
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
        (hmFor {
          imports = [ ./home/todd-base.nix ./home/todd-desktop.nix ];
          nixpkgs.overlays = [ claude-desktop.overlays.default herdr.overlays.default ];
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
        (hmFor {
          imports = [ ./home/todd-base.nix ];
        })
      ];
    };
  };
}
