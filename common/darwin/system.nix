{
  lib,
  machine,
  ...
}: {
  # Available options
  # https://daiderd.com/nix-darwin/manual/index.html#sec-options
  system = {
    primaryUser = "kradalby";

    defaults = {
      LaunchServices = {
        LSQuarantine = false;
      };
      NSGlobalDomain = {
        AppleInterfaceStyle = null; # Light mode when unset
        AppleInterfaceStyleSwitchesAutomatically = false;
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
      CustomUserPreferences = {
        "NSGlobalDomain" = {
          NSAutomaticTextCorrectionEnabled = false; # No autocorrect
        };

        # Screenshot settings
        "com.apple.screencapture" = {
          location = "~/Pictures/Screenshots";
          type = "png";
          disable-shadow = true;
        };

        # Prevent .DS_Store files on network and USB volumes
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };

        # Menu bar clock
        "com.apple.menuextra.clock" = {
          Show24Hour = true;
          ShowDate = 1; # Always show date
          DateFormat = "EEE d MMM HH:mm:ss";
          FlashDateSeparators = false;
          IsAnalog = false;
        };

        # Finder - open folders in new windows instead of tabs
        "com.apple.finder" = {
          FinderSpawnTab = false;
        };

        # Accessibility - zoom with scroll gesture
        "com.apple.universalaccess" = {
          closeViewScrollWheelToggle = true;
        };
      };

      dock = {
        autohide = true;
        orientation = "left";
        show-recents = false;
        tilesize = 16;
      };
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv"; # List view
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
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
}
