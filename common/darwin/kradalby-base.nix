# Personal base configuration for Kristoffer's Darwin (macOS) machines
# This contains shared settings across all personal Mac machines
{
  pkgs,
  config,
  machine,
  lib,
  stdenv,
  ...
}: {
  imports = [
    ../darwin.nix
    ../../pkgs/system.nix
    ../../pkgs/homebrew.nix
    ./syncthing.nix
  ];

  nix = {
    settings = {
      trusted-users = [machine.username];
      builders = "@/etc/nix/machines";
    };

    distributedBuilds = true;
    buildMachines = import ../buildmachines.nix;
  };

  users.users.kradalby = {
    name = machine.username;
    home = machine.homeDir;
  };

  home-manager = {
    verbose = true;
    backupFileExtension = "hm_bak~";
    useUserPackages = true;
    useGlobalPkgs = true;
    users."${machine.username}" = {
      imports = [
        ../../home
      ];
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  networking = {
    hostName = machine.hostname;
    computerName = machine.hostname;
    localHostName = machine.hostname;
  };

  system = {
    primaryUser = "kradalby";
    defaults = {
      smb.NetBIOSName = machine.hostname;
      dock.orientation = lib.mkForce "left";
    };

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 5;
  };
}
