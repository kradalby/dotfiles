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
  remoteBuilders = [
    "ssh://core.terra x86_64-linux"
    "ssh://core.tjoda x86_64-linux"
    "ssh://core.oracldn aarch64-linux"
    "ssh://dev.oracfurt aarch64-linux"
  ];
in
{
  imports = [
    ../../common/environment.nix
    ../../pkgs/system.nix
    ./syncthing.nix
    ./restic.nix
    # ./autossh.nix
  ];

  # on macOS, we need to make sure all SSH references
  # are empty so age dont go looking for services.openssh
  # which doesnt exist.
  age.identityPaths = [ "/Users/kradalby/.ssh/id_ed25519" ];

  services.nix-daemon = {
    enable = true;
  };

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
      builders = ${lib.concatStringsSep " ; " remoteBuilders}
    '';

    trustedUsers = [ machine.username ];

    # todo
    useSandbox = false;

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

      home.file = {
        ".ssh/authorized_keys".text = lib.concatStringsSep "\n" (sshKeys.main ++ sshKeys.kradalby);
      };
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

  homebrew = {
    enable = true;
    autoUpdate = true;

    cleanup = "zap"; # zap;

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

    brews = [
      # cdrkit in nixpkgs is only available for Linux
      "cdrtools"

      # exiftrans is a part of a linux only nix pkgs
      "exiftran"
    ];

    casks = [
      "1password"
      "1password-cli"
      "alacritty"
      "anki"
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
      "safari-technology-preview"
      "flameshot"
      "tunnelblick"

      # Decompilers and reverse engineering
      "temurin"
      "ghidra"
      "machoview"

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
      "Refined GitHub" = 1519867270;
      "Octotree" = 1457450145;
    };

  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
