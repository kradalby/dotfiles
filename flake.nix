{
  description = "kradalby's system config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, darwin, nixpkgs, home-manager }: {
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
        modules = [ ./darwin-configuration.nix ];
        specialArgs = {
          inherit machine home-manager;
        };
      };
  };

}
