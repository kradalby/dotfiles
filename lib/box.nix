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
    targetHost ? null,
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
              inherit targetHost;
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

  macBox = machine: pkgBase: homeBase: additionalModules:
    pkgBase.lib.darwinSystem {
      system = machine.arch;
      modules =
        (commonModules pkgBase)
        ++ additionalModules
        ++ [
          (./.. + "/machines/${machine.hostname}")
          homeBase.darwinModules.home-manager
          # inputs.nix-rosetta-builder.darwinModules.default
          # {nix.linux-builder.enable = true;}

          # nix.nixPath doesn't propagate to shell environment on Darwin,
          # so we set NIX_PATH explicitly to make nix-shell -p work
          {
            environment.variables.NIX_PATH = ["nixpkgs=${pkgBase}"];
          }
        ];
      specialArgs = {
        inherit inputs;
        inherit machine;
      };
    };

  mkColmenaFromNixOSConfigurations = nixosConfigurations:
    let
      base = {
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
            targetHost =
              if value._module.args.targetHost != null
              then value._module.args.targetHost
              else builtins.replaceStrings ["."] ["-"] name;
            inherit (value._module.args) tags;
          };
          nixpkgs.system = value.config.nixpkgs.system;
          imports = value._module.args.modules;
        })
        nixosConfigurations);
    in
      base;
}
