{
  description = "kradalby's system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-21.11-darwin";

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

    home-manager.url = "github:nix-community/home-manager/release-21.11";
    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    agenix.url = "github:ryantm/agenix";

    nur.url = "github:nix-community/NUR";

    fenix = {
      url = "github:nix-community/fenix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixops-plugged.url = github:lukebfox/nixops-plugged;
    # deploy-flake.url = "github:antifuchs/deploy-flake";
    deploy-rs.url = "github:serokell/deploy-rs";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
      # , nixops-plugged
      # , deploy-flake
    , deploy-rs
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

      commonModules = [
        # TODO: use when macOS is supported
        # agenix.nixosModules.age

        {
          nixpkgs.overlays = [
            nur.overlay
            overlay-pkgs
            fenix.overlay
            (import ./pkgs/overlays { inherit mach-nix; })
          ];
        }
      ];



      nixosBox = arch: base: homeBase: name: base.lib.nixosSystem {
        system = arch;
        modules = commonModules ++ [
          # TODO: remove when common
          agenix.nixosModules.age
          {
            system.configurationRevision =
              if self ? rev
              then self.rev
              else "DIRTY";
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
    in
    {

      nixosConfigurations = {
        "dev-terra" = nixosBox "x86_64-linux" nixpkgs-unstable home-manager-unstable "dev.terra";

        "core-oracldn" = nixosBox "aarch64-linux" nixpkgs-unstable home-manager-unstable "core.oracldn";
        "headscale-oracldn" = nixosBox "x86_64-linux" nixpkgs-unstable null "headscale.oracldn";

        "core-ntnu" = nixosBox "x86_64-linux" nixpkgs-unstable null "core.ntnu";

        "k3m1-terra" = nixosBox "x86_64-linux" nixpkgs-unstable null "k3m1.terra";
        "k3a1-terra" = nixosBox "x86_64-linux" nixpkgs-unstable null "k3a1.terra";
        "k3a2-terra" = nixosBox "x86_64-linux" nixpkgs-unstable null "k3a2.terra";

        # nixos-generate --system aarch64-linux -f sd-aarch64 -I nixpkgs=channel:nixos-unstable
        "home-ldn" = nixosBox "aarch64-linux" nixpkgs-unstable null "home.ldn";
        "core-ldn" = nixosBox "aarch64-linux" nixpkgs-unstable null "core.ldn";
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
          macBox machine darwin-unstable home-manager-unstable;
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
          homeOnly machine home-manager-unstable;
      };

      # deploy = {
      #   sshUser = "root";
      #   user = "root";
      #
      #   nodes = {
      #     # nix run github:serokell/deploy-rs -- .#"devterra"
      #     "devterra" = {
      #       hostname = "dev.terra.fap.no";
      #       fastConnection = true;
      #       profiles = {
      #         system = {
      #           path =
      #             deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations."dev.terra";
      #         };
      #       };
      #     };
      #   };
      # };

      # packages.aarch64-linux = {
      #   # nix build --system aarch64-linux .#"storage-bassan"
      #   "storage-bassan" = nixos-generators.nixosGenerate {
      #     pkgs = nixos.legacyPackages.aarch64-linux;
      #     modules =
      #       commonModules ++
      #       [ (./. + "/machines/storage.bassan") ];
      #     format = "sd-aarch64";
      #   };
      # };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
