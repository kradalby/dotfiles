{
  description = "kradalby's system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-22.05-darwin";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-staging.url = "github:NixOS/nixpkgs/staging";
    nixpkgs-staging-next.url = "github:NixOS/nixpkgs/staging-next";

    nixpkgs-hardware.url = "github:NixOS/nixos-hardware";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

    darwin-unstable.url = "github:lnl7/nix-darwin/master";
    darwin-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    darwin-master.url = "github:lnl7/nix-darwin/master";
    darwin-master.inputs.nixpkgs.follows = "nixpkgs-master";

    darwin-staging.url = "github:lnl7/nix-darwin/master";
    darwin-staging.inputs.nixpkgs.follows = "nixpkgs-staging";

    home-manager.url = "github:nix-community/home-manager/release-22.05";
    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    agenix.url = "github:ryantm/agenix";

    nur.url = "github:nix-community/NUR";

    fenix = {
      url = "github:nix-community/fenix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mach-nix.url = "github:DavHau/mach-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-unstable
    , nixpkgs-master
    , nixpkgs-staging
    , nixpkgs-staging-next
    , darwin
    , darwin-unstable
    , darwin-master
    , darwin-staging
    , home-manager
    , home-manager-unstable
    , agenix
    , nur
    , fenix
    , nixos-generators
    , mach-nix
    , flake-utils
    , ...
    } @ flakes:
    let
      overlay-pkgs = final: prev: {
        stable = import nixpkgs { inherit (final) system; };
        unstable = import nixpkgs-unstable { inherit (final) system; };
        master = import nixpkgs-master { inherit (final) system; };
        staging = import nixpkgs-staging { inherit (final) system; };
        staging-next = import nixpkgs-staging-next { inherit (final) system; };
      };

      overlays = [
        nur.overlay
        overlay-pkgs
        fenix.overlay
        (import ./pkgs/overlays { inherit mach-nix; })

      ];

      commonModules = [
        # TODO: use when macOS is supported
        # agenix.nixosModules.age

        {
          nixpkgs.overlays = overlays;
        }
      ];


      nixosBox = arch: base: homeBase: name: base.lib.nixosSystem {
        system = arch;
        modules = commonModules ++ [
          (import ./modules/linux.nix)

          # TODO: remove when common
          agenix.nixosModules.age
          {
            system.configurationRevision =
              self.rev or "DIRTY";
          }

          (./. + "/machines/${name}")
        ] ++ (
          if builtins.isNull homeBase then
            [ ]
          else [
            homeBase.nixosModules.home-manager
            ./common/home.nix
          ]
        );
        specialArgs = { inherit flakes; };
      };

      macBox = machine: base: homeBase: base.lib.darwinSystem {
        system = machine.arch;
        modules =
          let
            age = import ./modules/agenix.nix;
          in
          commonModules ++ [
            # TODO: Why does this cause infinite recurse
            # (import ./modules/macos.nix)

            (./. + "/machines/${machine.hostname}")
            homeBase.darwinModules.home-manager
            age
          ];
        specialArgs =
          {
            inherit flakes;
            inherit machine;
          };
      };

      homeOnly = machine: homeBase: homeBase.lib.homeManagerConfiguration {
        inherit (machine) username;
        system = machine.arch;
        homeDirectory = machine.homeDir;
        configuration.imports = [ ./home ];
        extraModules =
          commonModules ++
          [
            (./. + "/machines/${machine.hostname}")
          ];

      };

      mkColmenaFromNixOSConfigurations = nixosConfigurations:
        {
          meta = {
            nixpkgs = import nixpkgs {
              system = "x86_64-darwin";
              inherit overlays;
            };

            specialArgs = {
              inherit flakes;
            };
          };
        } // builtins.mapAttrs
          (name: value:
            {
              nixpkgs.system = value.config.nixpkgs.system;
              imports = value._module.args.modules;
            })
          nixosConfigurations;
    in
    {

      nixosConfigurations = {
        "dev.terra" = nixosBox "x86_64-linux" nixpkgs home-manager "dev.terra";

        "core.oracldn" = nixosBox "aarch64-linux" nixpkgs home-manager "core.oracldn";
        "headscale.oracldn" = nixosBox "x86_64-linux" nixpkgs null "headscale.oracldn";

        "dev.oracfurt" = nixosBox "aarch64-linux" nixpkgs home-manager "dev.oracfurt";

        "core.ntnu" = nixosBox "x86_64-linux" nixpkgs null "core.ntnu";

        "k3m1.terra" = nixosBox "x86_64-linux" nixpkgs null "k3m1.terra";
        "k3a1.terra" = nixosBox "x86_64-linux" nixpkgs null "k3a1.terra";
        "k3a2.terra" = nixosBox "x86_64-linux" nixpkgs null "k3a2.terra";

        # nixos-generate --system aarch64-linux -f sd-aarch64 -I nixpkgs=channel:nixos
        "home.ldn" = nixosBox "aarch64-linux" nixpkgs null "home.ldn";
        "core.ldn" = nixosBox "aarch64-linux" nixpkgs null "core.ldn";
        "storage.bassan" = nixosBox "aarch64-linux" nixpkgs null "storage.bassan";
        "core.tjoda" = nixosBox "x86_64-linux" nixpkgs null "core.tjoda";
      };

      # darwin-rebuild switch --flake .#kramacbook
      darwinConfigurations = {
        kramacbook =
          let
            machine = {
              arch = "x86_64-darwin";
              username = "kradalby";
              hostname = "kramacbook";
              homeDir = /Users/kradalby;
            };
          in
          macBox machine darwin home-manager;
      };

      homeConfigurations = {
        # nix run github:nix-community/home-manager/master --no-write-lock-file -- switch --flake .#multipass
        "kradalby" =
          let
            machine = {
              arch = "x86_64-linux";
              username = "kradalby";
              hostname = "kradalby.home";
              homeDir = "/home/kradalby";
            };
          in
          homeOnly machine home-manager;
      };

      colmena = mkColmenaFromNixOSConfigurations self.nixosConfigurations;

      packages.aarch64-linux = {
        # nix build --system aarch64-linux .#storage-bassan
        "storage-bassan" = nixos-generators.nixosGenerate {
          pkgs = nixpkgs.legacyPackages.aarch64-linux;
          inherit (self.nixosConfigurations."storage.bassan"._module.args) modules;
          specialArgs = { inherit flakes; };
          format = "sd-aarch64";
        };
      };
    };
}
