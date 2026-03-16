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
    allowLocalDeployment ? false,
  }:
    nixpkgs.lib.nixosSystem {
      modules =
        (commonModules nixpkgs)
        ++ modules
        ++ [
          {nixpkgs.hostPlatform = arch;}
          inputs.tailscale.nixosModules.default
          (import ../modules/linux.nix)
          {
            system.configurationRevision = rev;
          }

          (./.. + "/machines/${name}")

          {
            _module.args = {
              inherit tags;
              inherit targetHost;
              inherit allowLocalDeployment;
            };
          }
        ]
        ++ (
          if homeBase == null
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
      modules =
        (commonModules pkgBase)
        ++ additionalModules
        ++ [
          {nixpkgs.hostPlatform = machine.arch;}
          (./.. + "/machines/${machine.hostname}")
          homeBase.darwinModules.home-manager
          # inputs.nix-rosetta-builder.darwinModules.default
          # {nix.linux-builder.enable = true;}

          # pkgBase is nix-darwin (not nixpkgs), so we must override
          # the nix.nixPath set by commonModules to use the actual
          # nixpkgs-darwin input, otherwise NIX_PATH points at the
          # nix-darwin source and nix-shell -p cannot find <nixpkgs>.
          {
            nix.nixPath = lib.mkForce ["nixpkgs=${inputs.nixpkgs-darwin}"];
          }
        ];
      specialArgs = {
        inherit inputs;
        inherit machine;
      };
    };

  mkColmenaFromNixOSConfigurations = nixosConfigurations: let
    base =
      {
        meta = {
          machinesFile = /etc/nix/machines;
          # Reuse an existing NixOS host's pkgs to avoid a
          # redundant nixpkgs instantiation. All hosts use
          # buildOnTarget so this is only a fallback evaluator.
          nixpkgs =
            if nixosConfigurations ? "dev.ldn"
            then nixosConfigurations."dev.ldn".pkgs
            else
              import pkgs {
                system = "x86_64-linux";
                inherit overlays;
                config = {allowUnfree = true;};
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
            inherit (value._module.args) allowLocalDeployment;
          };
          imports = value._module.args.modules;
        })
        nixosConfigurations);
  in
    base;
}
