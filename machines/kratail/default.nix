{ pkgs
, config
, machine
, lib
, stdenv
, flakes
, ...
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
      trusted-users = [ machine.username ];
    };
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
      imports = [ ../../home ];

      # home.file = {
      #   ".ssh/authorized_keys".text = lib.concatStringsSep "\n" (sshKeys.main ++ sshKeys.kradalby);
      # };

      programs.git = {
        userEmail = lib.mkForce "kristoffer@tailscale.com";

        extraConfig = {
          user = {
            signingkey = lib.mkForce "/Users/kradalby/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/84675f6c5d4035e4e790ed5d73dd74e3.pub";
          };
        };
      };

      home.sessionVariables = {
        TS_NIX_SHELL_XCODE_VERSION = "14.2";
      };
    };
    # extraSpecialArgs = { inherit machine; };
  };

  networking = {
    hostName = machine.hostname;
    computerName = machine.hostname;
    localHostName = machine.hostname;
  };

  # Work stuff
  homebrew = {
    casks = [
      "tigervnc-viewer"
      "wireshark"
      "webex"
      "logi-options-plus"
      "monitorcontrol"
      "utm"
    ];
  };
  system.defaults.smb.NetBIOSName = machine.hostname;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  # system.stateVersion = 4;
}
