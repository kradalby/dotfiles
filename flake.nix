{
  description = "kradalby's system config";

  inputs = {
    nixos-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixos-unstable";

    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixos-unstable";
  };

  outputs =
    { self
    , nixos-unstable
    , darwin
    , home-manager-unstable
    }: {
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
