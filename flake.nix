{
  description = "NixOS system configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
  let
    hmBase = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-backup";
    };
  in
  {
    nixosConfigurations.nixos-dev = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./modules/common.nix
        ./hosts/nixos-dev/configuration.nix
        home-manager.nixosModules.home-manager
        (hmBase // {
          home-manager.users.todd = {
            imports = [ ./home/todd-base.nix ./home/todd-desktop.nix ];
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
