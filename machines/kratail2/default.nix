# Work Mac configuration (Tailscale)
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../common/darwin/kradalby-base.nix
    ./rustic.nix
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
    my.packages.ai.enable = false;

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

  # Userspace Tailscale node on the kradalby.no tailnet, alongside the
  # work Tailscale GUI app. kradalby.no is the default SaaS coordination
  # server, so no --login-server. No agenix on darwin → authenticate
  # interactively once with `tailscale-kradalby up`.
  services.tailscales.kradalby = {
    enable = true;
    extraSetFlags = [
      "--hostname=kradalby"
      "--ssh=true"
      "--accept-routes=true"
      "--accept-dns=true"
    ];

    # Expose the local ollama server on the tailnet as a Tailscale Service.
    # The bootstrap LaunchAgent turns this into `tailscale serve set-config`
    # + `serve advertise svc:ollama`. svc:ollama, a node tag, and an access
    # grant must be pre-defined in the kradalby.no admin console, and the node
    # re-authed with that tag: Services require tag-based node identity.
    services.ollama.endpoints = {
      "tcp:443" = "http://127.0.0.1:11434";
      "tcp:80" = "http://127.0.0.1:11434";
    };
  };

  # Headless ollama server. Owns 127.0.0.1:11434; the Tailscale Service above
  # proxies the tailnet to it. Reuses the existing ~/.ollama model store, so
  # already-pulled models are served as-is. The `ollama-app` GUI cask must not
  # run on this host (it would contend for the same port).
  homebrew.brews = ["ollama"];

  launchd.user.agents.ollama = {
    serviceConfig = {
      Label = "ollama";
      ProgramArguments = ["/opt/homebrew/bin/ollama" "serve"];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive"; # full GPU/perf, not background-throttled
      EnvironmentVariables = {
        OLLAMA_HOST = "127.0.0.1:11434"; # loopback only; tailnet via serve
        OLLAMA_KEEP_ALIVE = "30m"; # avoid reloading the large models
        PATH = "/opt/homebrew/bin:/usr/bin:/bin";
      };
      StandardOutPath = "/Users/kradalby/Library/Logs/ollama.log";
      StandardErrorPath = "/Users/kradalby/Library/Logs/ollama.log";
    };
  };

  services.syncthing.folders = {
    "/storage/software".enable = false;
    "/storage/books".enable = false;
    "/storage/pictures".enable = false;
    "/storage/backup".enable = false;
    "/fast/hugin".enable = false;
    "Sync".enable = false;

    "llm-git" = {
      id = "f6vv9-fsjeq";
      path = "/Users/kradalby/git";
      devices = ["kradalby-llm"];
      type = "sendreceive";
      ignorePatterns = [
        # macOS
        ".DS_Store"
        "._*"
        ".Spotlight-V100"
        ".Trashes"
        ".fseventsd"
        ".TemporaryItems"

        # VCS (keep .git for LLM access to history)
        ".jj"

        # Dependencies and build output
        "node_modules"
        ".gopath"
        "vendor"
        ".next"
        "dist"

        # Dev tools
        ".direnv"
        "result"
        ".devenv"
        ".pre-commit-hooks"
      ];
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
