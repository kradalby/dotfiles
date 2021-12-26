{ pkgs
, config
, machine
, ...
}:
{

  # sops.age.sshKeyPaths = [ "~/.ssh/id_ed25519" ];
  # sops.age.keyFile = "~/.config/sops/age/keys.txt";

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

  # System packages
  imports = [ ../../pkgs/system.nix ];

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

  networking.hostName = machine.hostname;

  # Available options
  # https://daiderd.com/nix-darwin/manual/index.html#sec-options
  system.defaults = {
    LaunchServices = { LSQuarantine = false; };
    NSGlobalDomain = {
      AppleInterfaceStyleSwitchesAutomatically = true;
      ApplePressAndHoldEnabled = false; # No accents
      KeyRepeat = 2; # I am speed
      InitialKeyRepeat = 15;
      AppleKeyboardUIMode = 3; # full control
      NSAutomaticQuoteSubstitutionEnabled = false; # No smart quotes
      NSAutomaticDashSubstitutionEnabled = false; # No em dash
      NSNavPanelExpandedStateForSaveMode =
        true; # Default to expanded "save" windows
      NSNavPanelExpandedStateForSaveMode2 = true; # don't ask
    };
    dock = {
      autohide = true;
      orientation = "right";
      show-recents = false;
      tilesize = 16;
    };
    finder = {
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

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
