# Work Mac configuration (Tailscale)
{
  config,
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

  services.syncthing.devices = {
    "kradalby-llm" = {id = "NCR7O6Z-XRY3NIN-XKHAZOE-2EUNNP5-PZ7H53H-47BK2YF-PDWEMQB-FLC4DQU";};
  };

  services.syncthing.folders = {
    "/storage/software".enable = false;
    "/storage/books".enable = false;
    "/storage/pictures".enable = false;
    "/storage/backup".enable = false;
    "/fast/hugin".enable = false;

    "Sync".devices = lib.mkForce (builtins.filter (d: d != "kradalby-llm") (builtins.attrNames config.services.syncthing.devices));

    "llm-git" = {
      id = "f6vv9-fsjeq";
      path = "/Users/kradalby/git";
      devices = ["kradalby-llm"];
      type = "sendreceive";
    };
  };

  homebrew = {
    casks = [
      "imageoptim"
      "monitorcontrol"
      "raycast"
      "slack"
      "slack-cli"
      "tigervnc"
      "utm"
      "zoom"
      "krisp"
    ];
  };
}
