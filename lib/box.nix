{
  pkgs,
  inputs,
  overlays,
  lib,
  rev,
  ...
}:
let
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
      nix.nixPath = [ "nixpkgs=${pkgBase}" ];
    }
  ];
in
{
  nixosBox =
    {
      arch,
      nixpkgs ? pkgs,
      homeBase ? null,
      name,
      modules ? [ ],
      # Default off: nodes don't build (max-jobs = 0 below). dev.ldn is the
      # sole builder and opts back in with buildOnTarget = true.
      buildOnTarget ? false,
    }:
    nixpkgs.lib.nixosSystem {
      modules =
        (commonModules nixpkgs)
        ++ modules
        ++ [
          { nixpkgs.hostPlatform = arch; }
          inputs.tailscale.nixosModules.default
          (import ../modules/linux.nix)
          {
            system.configurationRevision = rev;
          }

          # No local building unless this node builds on target.
          { nix.settings.max-jobs = lib.mkIf (!buildOnTarget) 0; }

          (./.. + "/machines/${name}")
        ]
        ++ (
          if homeBase == null then
            [ ]
          else
            [
              homeBase.nixosModules.home-manager
              ../common/home.nix
            ]
        );
      specialArgs = {
        inherit inputs;
      };
    };

  macBox =
    machine: pkgBase: homeBase: additionalModules:
    pkgBase.lib.darwinSystem {
      modules =
        (commonModules pkgBase)
        ++ additionalModules
        ++ [
          { nixpkgs.hostPlatform = machine.arch; }
          (./.. + "/machines/${machine.hostname}")
          homeBase.darwinModules.home-manager
          # inputs.nix-rosetta-builder.darwinModules.default
          # {nix.linux-builder.enable = true;}

          # pkgBase is nix-darwin (not nixpkgs), so we must override
          # the nix.nixPath set by commonModules to use the actual
          # nixpkgs-darwin input, otherwise NIX_PATH points at the
          # nix-darwin source and nix-shell -p cannot find <nixpkgs>.
          {
            nix.nixPath = lib.mkForce [ "nixpkgs=${inputs.nixpkgs-darwin}" ];
          }
        ];
      specialArgs = {
        inherit inputs;
        inherit machine;
      };
    };

}
