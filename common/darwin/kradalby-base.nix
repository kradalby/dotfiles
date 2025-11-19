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
    ../../modules/macos.nix
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
    extraSpecialArgs = {
      # Pass darwin config to home-manager so it can access services.ssh-agent-mux.socketPath
      osConfig = config;
    };
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
