{
  description = "kradalby's system config";

  inputs = {
    nixos-old.url = github:NixOS/nixpkgs/nixos-21.05;
    nixos.url = github:NixOS/nixpkgs/nixos-21.11;
    nixos-unstable.url = github:NixOS/nixpkgs/nixpkgs-unstable;
    nixos-master.url = github:NixOS/nixpkgs/master;

    nixos-hardware.url = github:NixOS/nixos-hardware;

    darwin.url = github:lnl7/nix-darwin/master;
    darwin.inputs.nixpkgs.follows = "nixos-unstable";

    home-manager-old.url = github:nix-community/home-manager/release-21.05;
    home-manager.url = github:nix-community/home-manager/release-21.11;
    home-manager-unstable.url = github:nix-community/home-manager/master;
    home-manager-unstable.inputs.nixpkgs.follows = "nixos-unstable";

    sops-nix.url = github:Mic92/sops-nix;

    nur.url = github:nix-community/NUR;

    fenix = {
      url = "github:nix-community/fenix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # Only pull from 'trunk' when channels are blocked by a Hydra jobset
    # failure or the 'unstable' channel has not otherwise updated recently for
    # some other reason.
    trunk.url = github:nixos/nixpkgs;

    # nixops-plugged.url = github:lukebfox/nixops-plugged;
    # deploy-flake.url = "github:antifuchs/deploy-flake";
    deploy-rs.url = github:serokell/deploy-rs;

    nixos-generators = {
      url = github:nix-community/nixos-generators;
      inputs.nixpkgs.follows = "nixos-unstable";
    };
  };

  outputs =
    { self
    , nixos-old
    , nixos
    , nixos-unstable
    , nixos-master
    , darwin
    , home-manager-old
    , home-manager
    , home-manager-unstable
    , sops-nix
    , nur
    , fenix
    , trunk
      # , nixops-plugged
      # , deploy-flake
    , deploy-rs
    , nixos-generators
    , ...
    } @ flakes:
    let
      overlay-pkgs = final: prev: {
        unstable = import nixos-unstable { system = final.system; };
        trunk = import trunk { system = final.system; };
      };

      commonModules = [
        sops-nix.nixosModules.sops

        ({ pkgs, ... }: {
          sops.defaultSopsFile = ./secrets.yaml;
        })

        ({ nixpkgs.overlays = [ nur.overlay overlay-pkgs fenix.overlay ]; })
      ];

      nixosBox = arch: base: homeBase: name: base.lib.nixosSystem {
        system = arch;
        modules = commonModules ++ [
          ({
            system.configurationRevision =
              if self ? rev
              then self.rev
              else "DIRTY";
          })

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

      macBox = machine: base: homeBase: darwin.lib.darwinSystem {
        system = machine.arch;
        modules = commonModules ++ [
          (./. + "/machines/${machine.hostname}")
          homeBase.darwinModules.home-manager
        ];
        specialArgs = {
          inherit flakes;
          inherit machine;
        };
      };

      homeOnly = machine: homeBase: homeBase.lib.homeManagerConfiguration {
        system = machine.arch;
        homeDirectory = machine.homeDir;
        username = machine.username;
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
        "dev-terra" = nixosBox "x86_64-linux" nixos home-manager-unstable "dev.terra";
        "core-ntnu" = nixosBox "x86_64-linux" nixos-unstable null "core.ntnu";

        # nixos-generate --system aarch64-linux -f sd-aarch64 -I nixpkgs=channel:nixos-unstable
        "storage-bassan" = nixosBox "aarch64-linux" nixos null "storage.bassan";
        "core-ldn" = nixosBox "aarch64-linux" nixos-unstable null "core.ldn";
        "home-ldn" = nixosBox "aarch64-linux" nixos-unstable null "home.ldn";
      };

      # darwin-rebuild switch --flake .#kramacbook
      darwinConfigurations = {
        kramacbook =
          let
            machine = {
              arch = "x86_64-darwin";
              username = "kradalby";
              hostname = "kramacbook";
              homeDir = "/Users/kradalby";
            };
          in
          macBox machine nixos-unstable home-manager-unstable;
      };

      homeConfigurations = {
        # nix run github:nix-community/home-manager/master --no-write-lock-file -- switch --flake .#multipass
        multipass =
          let
            machine = {
              arch = "x86_64-linux";
              username = "ubuntu";
              hostname = "multipass";
              homeDir = "/home/ubuntu";
            };
          in
          homeOnly machine home-manager-unstable;
      };

      deploy = {
        sshUser = "root";
        user = "root";

        nodes = {
          # nix run github:serokell/deploy-rs -- .#"devterra"
          "devterra" = {
            hostname = "dev.terra.fap.no";
            fastConnection = true;
            profiles = {
              system = {
                path =
                  deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations."dev.terra";
              };
            };
          };
        };
      };

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

