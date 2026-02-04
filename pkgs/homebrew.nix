_: {
  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "zap"; # zap;
      autoUpdate = true;
      upgrade = true;
    };

    brews = [
      # cdrkit in nixpkgs is only available for Linux
      "cdrtools"

      # exiftrans is a part of a linux only nix pkgs
      "exiftran"

      # PAM module to make TouchID sudo work in tmux
      "pam-reattach"

      # Incus isnt buildable from nixpkgs for macOS
      "incus"

      # Terminal notifications for done.fish integration
      "terminal-notifier"
    ];

    casks = [
      # Must have
      "1password"
      "1password-cli"
      "firefox"
      "google-chrome"
      "safari-technology-preview"
      "rectangle" # window manager
      "ghostty" # GPU-accelerated terminal
      "hiddenbar" # hide menu bar icons
      "secretive" # Secure Enclave SSH agent
      "shottr" # fast screenshot tool
      "the-unarchiver"
      "obsidian" # knowledge base
      "zed@preview" # preview build of Zed editor
      "maccy" # clipboard manager
      "finicky" # rules-based browser chooser

      # Messages
      "signal" # secure messenger
      "discord" # community chat

      # Productivity
      "balenaetcher" # USB/imager tool
      "gas-mask" # hosts file manager
      "geotag-photos-pro" # photo geotagging
      "remote-desktop-manager"
      "transmit" # SFTP/file transfer client

      # Quiz
      "youtube-to-mp3"
      "audacity" # audio editor

      # Media & play
      "handbrake-app" # video transcoder
      "iina" # modern video player
      "vlc" # swiss-army media player
      "openttd" # Transport Tycoon game
      "steam" # game launcher
      "calibre" # book management

      # AI & experiments
      "chatgpt" # OpenAI desktop client
      "claude" # Anthropic desktop client
      "cursor" # AI-focused code editor
      "ollama-app" # local LLM runner GUI
      "antigravity" # Google's experimental VSCode fork
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Amphetamine" = 937984704; # keep the Mac awake
      "Boop" = 1518425043; # text transformation scratchpad
      "Discovery" = 1381004916; # Bonjour/mDNS browser
      "Disk Speed Test" = 425264550;
      "Key Codes" = 414568915; # show keyboard key codes
      "MQTT Explorer" = 1455214828; # MQTT broker inspector
      "Patterns" = 429449079; # regex tester
      "Pixelmator Pro" = 1289583905; # photo editor
      "Refined GitHub" = 1519867270; # GitHub UI tweaks
      "TestFlight" = 899247664;
      "WhatsApp" = 310633997;
      "Wunderbar" = 6479203386; # customizable menu bar workspace
      "Xcode" = 497799835;
      "Yubico Authenticator" = 1497506650;
      # "Tailscale" = 1475387142;
      # "WireGuard" = 1451685025;
    };
  };
}
