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

    # Host the local ollama server on the tailnet as svc:ollama. A Service
    # host must use tag-based identity, so this node runs as tag:kradalby
    # (its SSH/identity is then governed by tag grants, not the user). The
    # bootstrap LaunchAgent runs `serve set-config` + `serve advertise
    # svc:ollama`. svc:ollama, tag:kradalby (tagOwners + autoApprovers), and
    # an access grant must exist in the kradalby.no admin console, and the
    # node authed with the tag once:
    #   tailscale-kradalby up --advertise-tags=tag:kradalby --ssh \
    #     --accept-routes --accept-dns --hostname=kradalby
    #
    # Points at the caddy Host-rewrite proxy (11435), not ollama directly:
    # ollama's DNS-rebinding guard 403s any non-loopback Host, and
    # `tailscale serve` forwards the tailnet Host unchanged. The proxy
    # rewrites Host to the loopback upstream so the guard passes, while
    # ollama itself stays bound to loopback (no LAN exposure).
    services.ollama.endpoints = {
      "tcp:443" = "http://127.0.0.1:11435";
      "tcp:80" = "http://127.0.0.1:11435";
    };
  };

  # Headless ollama server. Owns 127.0.0.1:11434, loopback only. Reuses the
  # existing ~/.ollama model store, so already-pulled models are served as-is.
  #
  # Runs the binary bundled inside the ollama-app cask, not the homebrew
  # `ollama` formula: that formula ships without the llama-server runner /
  # Metal libs, so it can't run any model (GPU discovery fails, falls back to
  # a CPU runner that doesn't exist). The .app bundle carries llama-server and
  # the ggml/llama dylibs and self-locates them relative to the binary, giving
  # Metal GPU inference. The GUI app must stay quit (not a Login Item) so it
  # doesn't contend for the port — this agent is the only server.
  launchd.user.agents.ollama = {
    serviceConfig = {
      Label = "ollama";
      ProgramArguments = ["/Applications/Ollama.app/Contents/Resources/ollama" "serve"];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive"; # full GPU/perf, not background-throttled
      EnvironmentVariables = {
        OLLAMA_HOST = "127.0.0.1:11434"; # loopback only; tailnet via serve
        OLLAMA_KEEP_ALIVE = "30m"; # avoid reloading the large models
        PATH = "/usr/bin:/bin";
      };
      StandardOutPath = "/Users/kradalby/Library/Logs/ollama.log";
      StandardErrorPath = "/Users/kradalby/Library/Logs/ollama.log";
    };
  };

  # Host-rewrite proxy in front of ollama. tailscale serve forwards the tailnet
  # Host (ollama.dalby.ts.net), which ollama's loopback DNS-rebinding guard
  # rejects with 403. caddy --change-host-header rewrites Host to the loopback
  # upstream (127.0.0.1:11434), which the guard accepts. Loopback-only, so the
  # tailnet grant stays the sole access control.
  launchd.user.agents.ollama-proxy = {
    serviceConfig = {
      Label = "ollama-proxy";
      ProgramArguments = [
        "${pkgs.caddy}/bin/caddy"
        "reverse-proxy"
        "--from"
        "http://127.0.0.1:11435"
        "--to"
        "127.0.0.1:11434"
        "--change-host-header"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      StandardOutPath = "/Users/kradalby/Library/Logs/ollama-proxy.log";
      StandardErrorPath = "/Users/kradalby/Library/Logs/ollama-proxy.log";
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
