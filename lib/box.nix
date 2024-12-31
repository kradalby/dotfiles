{
  pkgs,
  inputs,
  overlays,
  lib,
  rev ? "DIRTY",
  ...
}: let
  commonModules = pkgBase: [
    inputs.ragenix.nixosModules.age
    {
      nixpkgs = {
        inherit overlays;
        config.allowUnfree = true;
      };
    }
    {
      # pin system nixpkgs to the same version as the flake input
      # (don't see a way to declaratively set channels but this seems to work fine?)
      nix.nixPath = ["nixpkgs=${pkgBase}"];
    }
  ];
in {
  nixosBox = {
    arch,
    nixpkgs ? pkgs,
    homeBase ? null,
    name,
    tags ? [],
    modules ? [],
  }:
    nixpkgs.lib.nixosSystem {
      system = arch;
      modules =
        (commonModules nixpkgs)
        ++ modules
        ++ [
          (import ../modules/linux.nix)
          {
            system.configurationRevision = rev;
          }

          (./.. + "/machines/${name}")

          {
            _module.args = {
              inherit tags;
            };
          }
        ]
        ++ (
          if builtins.isNull homeBase
          then []
          else [
            homeBase.nixosModules.home-manager
            ../common/home.nix
          ]
        );
      specialArgs = {
        inherit inputs;
      };
    };

  macBox = machine: pkgBase: homeBase:
    pkgBase.lib.darwinSystem {
      system = machine.arch;
      modules =
        (commonModules pkgBase)
        ++ [
          (./.. + "/machines/${machine.hostname}")
          homeBase.darwinModules.home-manager
          # inputs.nix-rosetta-builder.darwinModules.default
          # {nix.linux-builder.enable = true;}
        ];
      specialArgs = {
        inherit inputs;
        inherit machine;
      };
    };

  mkColmenaFromNixOSConfigurations = nixosConfigurations:
    {
      meta = {
        machinesFile = /etc/nix/machines;
        nixpkgs = import pkgs {
          system = "x86_64-linux";
          inherit overlays;
        };

        specialArgs = {
          inherit inputs;
        };
      };
    }
    // (builtins.mapAttrs
      (name: value: {
        deployment = {
          buildOnTarget = true;
          # Replace hostname with tailscale hostname to use tailscale auth.
          targetHost = builtins.replaceStrings ["."] ["-"] name;
          inherit (value._module.args) tags;
        };
        nixpkgs.system = value.config.nixpkgs.system;
        imports = value._module.args.modules;
      })
      nixosConfigurations);
}
