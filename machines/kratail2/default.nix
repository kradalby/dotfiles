{
  pkgs,
  config,
  machine,
  lib,
  stdenv,
  ...
}: {
  imports = [
    ../../common/darwin.nix

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
    buildMachines = import ../../common/buildmachines.nix;
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
        # ./scripts.nix
      ];

      programs.git = {
        userEmail = lib.mkForce "kristoffer@tailscale.com";
      };

      home.sessionVariables = {
        TS_NIX_SHELL_XCODE_VERSION = "15.4";
        TS_NIX_SHELL_XCODE_WRAPPER_DISABLED = "1";
      };
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  networking = {
    hostName = machine.hostname;
    computerName = machine.hostname;
    localHostName = machine.hostname;
  };

  # Work stuff
  homebrew = {
    casks = [
      "google-chrome"
      "imageoptim"
      "monitorcontrol"
      "tigervnc-viewer"
      "utm"
      "wireshark"
      "zoom"
      "slack-cli"
    ];
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
