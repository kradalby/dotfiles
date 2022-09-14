_: {
  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "zap"; # zap;
      autoUpdate = true;
      upgrade = true;
    };

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
      # "tripmode"
      "visual-studio-code"
      "safari-technology-preview"
      # "flameshot"
      "shottr"
      "tunnelblick"
      "secretive"

      # Decompilers and reverse engineering
      "temurin"
      "ghidra"
      "machoview"

      # Maybe
      "monitorcontrol"
      "logi-options-plus"
      # "multipass"
      "docker"
    ];

    # TODO: why does some of these not work?
    masApps = {
      "1Password for Safari" = 1569813296;
      "Amphetamine" = 937984704;
      "Discovery" = 1381004916;
      "Disk Speed Test" = 425264550;
      "Key Codes" = 414568915;
      "MQTT Explorer" = 1455214828;
      "Messenger" = 1480068668;
      "Microsoft Remote Desktop" = 1295203466;
      "Octotree" = 1457450145;
      "Patterns" = 429449079;
      "Pixelmator Pro" = 1289583905;
      "Refined GitHub" = 1519867270;
      "Tailscale" = 1475387142;
      "WhatsApp" = 1147396723;
      "WireGuard" = 1451685025;
      "Xcode" = 497799835;
      "Yubico Authenticator" = 1497506650;
    };

  };



}
