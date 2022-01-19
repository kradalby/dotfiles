{ pkgs
, config
, machine
, lib
, stdenv
, ...
}:
{
  imports = [
    ../../pkgs/system.nix
    ./syncthing.nix
    ./restic.nix
    # ./autossh.nix
  ];

  # on macOS, we need to make sure all SSH references
  # are empty so sops dont go looking for services.openssh
  # which doesnt exist.
  sops.gnupg.sshKeyPaths = lib.mkForce [ ];
  sops.age.sshKeyPaths = lib.mkForce [ ];
  sops.age.keyFile = "/Users/kradalby/.config/sops/age/keys.txt";

  # sops.secrets.restic-kramacbook-token = { };
  # environment.etc.testy.text = ''
  #   ${config.sops.secrets.restic-kramacbook-token.path}
  # '';

  services.nix-daemon = {
    enable = true;
  };

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    trustedUsers = [ machine.username ];

    # todo
    useSandbox = false;
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
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
    };
    # extraSpecialArgs = { inherit machine; };
  };

  networking = {
    hostName = machine.hostname;
    computerName = machine.hostname;
    localHostName = machine.hostname;
  };

  fonts = {
    enableFontDir = true;
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

  homebrew = {
    enable = true;
    autoUpdate = true;

    cleanup = "none"; # zap;

    taps = [
      "apparition47/tap"
      "dteoh/sqa"
      "homebrew/bundle"
      "homebrew/cask"
      "homebrew/cask-drivers"
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/core"
      "homebrew/services"
      "ibm-swift/kitura"
      "jotta/cli"
      "kradalby/tap"
      "lukakerr/things"
      "minio/stable"
      "sachaos/tap"
    ];

    brews = [ ];

    casks = [
      "1password"
      "1password-cli"
      "alacritty"
      "balenaetcher"
      "calibre"
      "discord"
      "firefox"
      "free-ruler"
      "gas-mask"
      "geotag-photos-pro"
      "handbrake"
      "hex-fiend"
      "iina"
      "little-snitch"
      "maccy"
      "openttd"
      "protonmail-bridge"
      "rectangle"
      "signal"
      "slack"
      "slowquitapps"
      # "syncthing"
      "the-unarchiver"
      "tor-browser"
      "transmission"
      "transmit"
      "tripmode"
      "visual-studio-code"

      # Maybe
      "monitorcontrol"
      "multipass"
      "docker"
    ];

    masApps = {
      "Amphetamine" = 937984704;
      "Apple Configurator 2" = 1037126344;
      "Discovery" = 1381004916;
      "Disk Speed Test" = 425264550;
      "Key Codes" = 414568915;
      "Messenger" = 1480068668;
      "Microsoft Remote Desktop" = 1295203466;
      "MQTT Explorer" = 1455214828;
      "Patterns" = 429449079;
      "Pixelmator Pro" = 1289583905;
      "Tailscale" = 1475387142;
      "WhatsApp" = 1147396723;
      "WireGuard" = 1451685025;
      "Xcode" = 497799835;
    };

  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
