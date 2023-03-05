{ pkgs
, config
, machine
, lib
, stdenv
, flakes
, ...
}:
let
  sshKeys = import ../../metadata/ssh.nix;
in
{
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
  age.identityPaths = [ "/Users/kradalby/.ssh/id_ed25519" ];

  nix = {
    extraOptions = lib.mkForce ''
      experimental-features = nix-command flakes
    '';

    settings = {
      trusted-users = [ machine.username ];
    };

    distributedBuilds = true;

    # NOTE: Public host key verification seem broken from
    # at least macOS, we need to add the key manually by
    # adding the base64 key ourselves:
    # base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub
    buildMachines = [
      # {
      #   hostName = "core.terra.fap.no";
      #   systems = ["x86_64-linux"];
      #   sshUser = "root";
      #   sshKey = "/Users/kradalby/.ssh/id_ed25519";
      #   maxJobs = 5;
      #   supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
      #
      #   publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdFenhqcHM1OGFJcncxWnhnRFV1ajFXN1QzQng2WmJPNlEzNGEweGoyQkEgcm9vdEBjb3JlCg==";
      # }
      {
        hostName = "core.tjoda.fap.no";
        systems = [ "x86_64-linux" ];
        sshUser = "root";
        sshKey = "/Users/kradalby/.ssh/id_ed25519";
        maxJobs = 3;
        supportedFeatures = [ "big-parallel" "kvm" "nixos-test" ];
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUJTcUVoTExkczhzaHc4SE1PU3BOOFVNQkZqTFBUQ3lnMVRqSEtxWHZtMVcgcm9vdEBuaXhvcwo=";
      }
      {
        hostName = "core.oracldn.fap.no";
        systems = [ "aarch64-linux" ];
        sshUser = "root";
        sshKey = "/Users/kradalby/.ssh/id_ed25519";
        maxJobs = 3;
        supportedFeatures = [ "big-parallel" "kvm" "nixos-test" ];
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdFZTllSU1mNDYyWlFoRThObDlqeVVzY1J0VFRZZUFJUFJOMmt2TzNjZEMgcm9vdEBjb3JlCg==";
      }
      {
        hostName = "dev.oracfurt.fap.no";
        systems = [ "aarch64-linux" ];
        sshUser = "kradalby";
        sshKey = "/Users/kradalby/.ssh/id_ed25519";
        maxJobs = 3;
        supportedFeatures = [ "big-parallel" "kvm" "nixos-test" ];
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUU2NXMvaFJuMzR2NVVOaFNJQzgvSk4vNDUyaExkcW4xMzFnVnFxQlRQbmwgcm9vdEBkZXYK";
      }
    ];
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
      "macfuse"
      "transmission"
      "garmin-express"
    ];
  };

  system.defaults.smb.NetBIOSName = machine.hostname;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  # system.stateVersion = 4;
}
