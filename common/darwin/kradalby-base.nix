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

      # macOS Safari settings - disable autofill and password manager
      targets.darwin.defaults = {
        "com.apple.Safari" = {
          AutoFillPasswords = false;
          AutoFillCreditCardData = false;
          AutoFillMiscellaneousForms = false;
          AutoFillFromAddressBook = false;
        };
      };
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
      trackpad.TrackpadThreeFingerDrag = true;

      # Finder: Open folders in new windows instead of tabs
      # finder.FinderSpawnTab = false;
    };

    # Enable Apple Remote Management for user kradalby
    activationScripts.remoteManagement.text = ''
      # Enable Apple Remote Management (ARD)
      echo "Configuring Apple Remote Management..."
      /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
        -activate \
        -configure -allowAccessFor -specifiedUsers \
        -configure -users kradalby -access -on -privs -all \
        -restart -agent -console 2>&1 || echo "Note: Remote Management may require manual approval in System Preferences on macOS 10.14+"
    '';

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 5;
  };
}
