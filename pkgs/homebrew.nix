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
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/services"
      "ibm-swift/kitura"
      "jotta/cli"
      "kradalby/tap"
      "lukakerr/things"
      "minio/stable"
      "sachaos/tap"
      "cirruslabs/cli"
    ];

    brews = [
      # cdrkit in nixpkgs is only available for Linux
      "cdrtools"

      # exiftrans is a part of a linux only nix pkgs
      "exiftran"

      # PAM module to make TouchID sudo work in tmux
      "pam-reattach"

      # CI/VM
      # "tart"
      "softnet"
    ];

    casks = [
      "1password"
      "1password-cli"
      "alacritty"
      "anki"
      "balenaetcher"
      "chatgpt"
      "deskpad"
      "discord"
      "element"
      "firefox"
      "gas-mask"
      "geotag-photos-pro"
      "ghostty"
      "handbrake"
      "hiddenbar"
      "hot"
      "iina"
      "logitech-g-hub"
      "maccy"
      "obsidian"
      "openttd"
      "raycast"
      "rectangle"
      "remote-desktop-manager"
      "safari-technology-preview"
      "secretive"
      "shottr"
      "signal"
      "slack"
      "steam"
      "the-unarchiver"
      "transmit"
      "zed@preview"
      "youtube-to-mp3"
      "ollama"
      "finicky"
      # "docker" // TODO: remove if colima + docker works
      # "free-ruler"
      # "hex-fiend"
      # "little-snitch"
      # "slowquitapps"
      # "tor-browser"
      # "transmission"
      # "tunnelblick"
      # "visual-studio-code"

      # For quiz!
      "vlc"
      "audacity"

      # Decompilers and reverse engineering
      # "temurin"
      # "ghidra"
      # "machoview"
      "vmware-fusion"
    ];

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
      # "Tailscale" = 1475387142;
      "WhatsApp" = 1147396723;
      # "WireGuard" = 1451685025;
      "Xcode" = 497799835;
      "Yubico Authenticator" = 1497506650;
      "Wunderbar" = 6479203386;
      "TestFlight" = 899247664;
    };
  };
}
