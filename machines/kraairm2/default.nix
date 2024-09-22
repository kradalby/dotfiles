{
  pkgs,
  config,
  machine,
  lib,
  stdenv,
  flakes,
  ...
}: let
  sshKeys = import ../../metadata/ssh.nix;
in {
  imports = [
    ../../common/darwin.nix

    ../../pkgs/system.nix
    ../../pkgs/homebrew.nix
    ./syncthing.nix
    ./restic.nix
  ];

  # on macOS, we need to make sure all SSH references
  # are empty so age dont go looking for services.openssh
  # which doesnt exist.
  age.identityPaths = ["/Users/kradalby/.ssh/id_ed25519"];

  nix = {
    extraOptions = lib.mkForce ''
      experimental-features = nix-command flakes
    '';

    settings = {
      trusted-users = [machine.username];
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
      imports = [../../home];

      home.file = {
        ".ssh/authorized_keys".text = lib.concatStringsSep "\n" (sshKeys.main ++ sshKeys.kradalby);
      };

      programs.git = {
        extraConfig = {
          user = {
            signingkey = lib.mkForce "/Users/kradalby/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/7e4532c4047204869abea854f115a302.pub";
          };
        };
      };
    };
    # extraSpecialArgs = { inherit machine; };
  };

  networking = {
    hostName = machine.hostname;
    computerName = machine.hostname;
    localHostName = machine.hostname;
  };

  homebrew = {
    casks = [
      # "vmware-fusion"
      "battle-net"
      "macfuse"
      "transmission"
      "garmin-express"
      "calibre"
    ];
  };

  system.defaults.smb.NetBIOSName = machine.hostname;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
