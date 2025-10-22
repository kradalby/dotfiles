# Work Mac configuration (Tailscale)
{
  lib,
  ...
}: {
  imports = [
    ../../common/darwin/kradalby-base.nix
  ];

  # Work-specific overrides
  home-manager.users.kradalby = {
    programs.git = {
      userEmail = lib.mkForce "kristoffer@tailscale.com";
    };

    home.sessionVariables = {
      TS_NIX_SHELL_XCODE_VERSION = "15.4";
      TS_NIX_SHELL_XCODE_WRAPPER_DISABLED = "1";
    };
  };

  homebrew = {
    casks = [
      "google-chrome"
      "imageoptim"
      "monitorcontrol"
      "tigervnc-viewer"
      "utm"
      # "wireshark"
      "zoom"
      "slack-cli"
      "logi-options+"
    ];
  };
}
