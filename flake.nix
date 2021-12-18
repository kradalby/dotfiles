{
  description = "kradalby's system config";

  inputs = {
    nixos-old.url = github:NixOS/nixpkgs/nixos-21.05;
    nixos.url = github:NixOS/nixpkgs/nixos-21.11;
    nixos-unstable.url = github:nixos/nixpkgs/nixpkgs-unstable;

    nixos-hardware.url = github:NixOS/nixos-hardware;

    darwin.url = github:lnl7/nix-darwin/master;
    darwin.inputs.nixpkgs.follows = "nixos-unstable";

    home-manager-old.url = github:nix-community/home-manager/release-21.05;
    home-manager.url = github:nix-community/home-manager/release-21.11;
    home-manager-unstable.url = github:nix-community/home-manager/master;
    home-manager-unstable.inputs.nixpkgs.follows = "nixos-unstable";

    nur.url = github:nix-community/NUR;
  };

  outputs =
    { self
    , nixos-old
    , nixos
    , nixos-unstable
    , darwin
    , home-manager-old
    , home-manager
    , home-manager-unstable
    , nur
    , ...
    } @ flakes: {
      darwinConfigurations.kramacbook =
        let
          system = "x86_64-darwin";
          machine = {
            username = "kradalby";
            hostname = "kramacbook";
            homeDir = "/Users/kradalby";
          };
        in
        darwin.lib.darwinSystem {
          inherit system;
          modules = [
            ./darwin-configuration.nix
            home-manager-unstable.darwinModules.home-manager
          ];
          specialArgs = {
            inherit machine;
          };
        };
    };

}
