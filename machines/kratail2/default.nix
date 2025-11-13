# Work Mac configuration (Tailscale)
{
  lib,
  pkgs,
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

  # Persistent SSH connection to krair with agent forwarding
  services.autossh.sessions = [
    {
      name = "krair-agent-forward";
      user = "kradalby";
      monitoringPort = 0; # Disable AutoSSH monitoring, rely on SSH keep-alive
      extraArguments = "-A -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 krair";
    }
  ];

  homebrew = {
    casks = [
      "google-chrome"
      "imageoptim"
      "monitorcontrol"
      "tigervnc-viewer"
      "utm"
      "zoom"
      "slack-cli"
    ];
  };
}
