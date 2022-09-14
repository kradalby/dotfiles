{ pkgs
, config
, machine
, lib
, stdenv
, flakes
, ...
}:
{
  imports = [
    ../../common/environment.nix
    ../../pkgs/system.nix
    ../../pkgs/homebrew.nix
  ];

  # on macOS, we need to make sure all SSH references
  # are empty so age dont go looking for services.openssh
  # which doesnt exist.
  # age.identityPaths = [ "/Users/kradalby/.ssh/id_ed25519" ];

  services.nix-daemon = {
    enable = true;
  };

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    settings = {
      trusted-users = [ machine.username ];

      # todo
      sandbox = false;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 5d";
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true; # TODO: Remove
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

      programs.git.userEmail = lib.mkForce "kristoffer@tailscale.com";
    };
    # extraSpecialArgs = { inherit machine; };
  };

  networking = {
    hostName = machine.hostname;
    computerName = machine.hostname;
    localHostName = machine.hostname;
  };

  fonts = {
    fontDir.enable = true;
    fonts = [ pkgs.jetbrains-mono pkgs.nerdfonts ];
  };

  # Available options
  # https://daiderd.com/nix-darwin/manual/index.html#sec-options
  system = {
    defaults = {
      LaunchServices = {
        LSQuarantine = false;
      };
      NSGlobalDomain = {
        AppleInterfaceStyleSwitchesAutomatically = true;
        AppleKeyboardUIMode = 3; # full control
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        ApplePressAndHoldEnabled = false; # No accents
        AppleShowAllExtensions = true;
        AppleTemperatureUnit = "Celsius";
        InitialKeyRepeat = 15;
        KeyRepeat = 2; # I am speed
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false; # No em dash
        NSAutomaticQuoteSubstitutionEnabled = false; # No smart quotes
        NSAutomaticSpellingCorrectionEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true; # Default to expanded "save" windows
        NSNavPanelExpandedStateForSaveMode2 = true; # don't ask
      };
      dock = {
        autohide = true;
        orientation = "right";
        show-recents = false;
        tilesize = 16;
      };
      finder = {
        QuitMenuItem = true;

        AppleShowAllExtensions = true;
        _FXShowPosixPathInTitle = true;
      };
      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
      loginwindow.GuestEnabled = false;
      smb.NetBIOSName = machine.hostname;
    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  # system.stateVersion = 4;
}
