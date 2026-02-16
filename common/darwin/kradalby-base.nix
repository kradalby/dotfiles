# Personal base configuration for Kristoffer's Darwin (macOS) machines
# This contains shared settings across all personal Mac machines
{
  pkgs,
  config,
  machine,
  lib,
  stdenv,
  inputs,
  ...
}: let
  # Linux builder configuration for cross-compiling to aarch64-linux
  #
  # Bootstrap process for new machines:
  # 1. First run with useRosettaBuilder = false (uses nix.linux-builder)
  #    This bootstraps the basic linux builder using Apple Virtualization.framework
  # 2. Once the linux-builder is working, set useRosettaBuilder = true
  #    This builds and enables the rosetta-based builder which is faster
  #
  # To bootstrap: temporarily set to false, rebuild, then set back to true
  useRosettaBuilder = true;
in {
  imports = [
    ../darwin.nix
    ../../pkgs/system.nix
    ../../pkgs/homebrew.nix
    ./syncthing.nix
    ../../modules/macos.nix
  ];

  nix-rosetta-builder = {
    enable = useRosettaBuilder;
    speedFactor = 10; # Highest priority - local builder
  };
  nix.linux-builder.enable = !useRosettaBuilder;

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
    sharedModules = [inputs.nix-index-database.homeModules.nix-index];
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
          AutoOpenSafeDownloads = false;
          ShowOverlayStatusBar = true;
          ShowFullURLInSmartSearchField = true;
          IncludeDevelopMenu = true;
          WebKitDeveloperExtrasEnabledPreferenceKey = true;
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

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
