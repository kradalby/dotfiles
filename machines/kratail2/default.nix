# Work Mac configuration (Tailscale)
{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../common/darwin/kradalby-base.nix
  ];

  # Configure SSH agent mux for work machine
  services.ssh-agent-mux = {
    enable = true;
    agentSockets = [
      "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      "~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
      "~/.ssh/yubikey-agent.sock"
    ];
    watchForSSHForward = true; # Automatically detect and use forwarded agents
  };

  # Work-specific overrides
  home-manager.users.kradalby = {
    programs.git.settings.user = {
      email = lib.mkForce "kristoffer@tailscale.com";
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
      monitoringPort = 20000;
      extraArguments = "-A -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 krair";
    }
  ];

  # Launchd logs: /Users/kradalby/Library/Logs/autossh-krair-agent-forward[-error].log
  launchd.daemons.autossh-krair-agent-forward.serviceConfig = {
    StandardOutPath = "/Users/kradalby/Library/Logs/autossh-krair-agent-forward.log";
    StandardErrorPath = "/Users/kradalby/Library/Logs/autossh-krair-agent-forward-error.log";
  };

  homebrew = {
    casks = [
      "imageoptim"
      "monitorcontrol"
      "raycast"
      "slack"
      "slack-cli"
      "tigervnc-viewer"
      "utm"
      "zoom"
      "krisp"
    ];
  };
}
