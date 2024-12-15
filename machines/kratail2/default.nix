{
  pkgs,
  config,
  machine,
  lib,
  stdenv,
  flakes,
  ...
}: {
  imports = [
    ../../common/darwin.nix

    ../../pkgs/system.nix
    ../../pkgs/homebrew.nix
  ];

  # on macOS, we need to make sure all SSH references
  # are empty so age dont go looking for services.openssh
  # which doesnt exist.
  # age.identityPaths = [ "/Users/kradalby/.ssh/id_ed25519" ];

  nix = {
    extraOptions = lib.mkForce ''
      experimental-features = nix-command flakes
    '';

    settings = {
      trusted-users = [machine.username];
    };
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

      # home.file = {
      #   ".ssh/authorized_keys".text = lib.concatStringsSep "\n" (sshKeys.main ++ sshKeys.kradalby);
      # };

      programs.git = {
        userEmail = lib.mkForce "kristoffer@tailscale.com";
      };

      home.sessionVariables = {
        TS_NIX_SHELL_XCODE_VERSION = "15.4";
        TS_NIX_SHELL_XCODE_WRAPPER_DISABLED = "1";
      };
    };
    # extraSpecialArgs = { inherit machine; };
  };

  security.pam.enableSudoTouchIdAuth = true;

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
    defaults = {
      smb.NetBIOSName = machine.hostname;
      dock.orientation = lib.mkForce "left";
    };

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 5;
  };
}
