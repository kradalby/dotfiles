{ config, lib, flakes, pkgs, ... }:
{

  i18n.defaultLocale = "en_US.UTF-8";

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";
    # settings = {
    #   auto-optimise-store = true;
    #   sandbox = true;
    #   trusted-users = [ "kradalby" ];
    # };

    gc = {
      automatic = true;
      dates = "03:15";
      options = "--delete-older-than 10d";
    };

    optimise = {
      automatic = true;
      dates = [ "03:45" ];
    };

    registry = {
      nixos.flake = flakes.nixpkgs;
      nixos-unstable.flake = flakes.nixpkgs-unstable;
      nixos-master.flake = flakes.nixpkgs-master;
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  imports = [ ../pkgs/system.nix ];
}
