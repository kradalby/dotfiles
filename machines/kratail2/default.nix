# Work Mac configuration (Tailscale)
{ config
, lib
, pkgs
, ...
}:
let
  # Shared with home/ai.nix (opencode) so the served tags and the model list
  # can never drift.
  registry = import ../../common/models.nix;
  ollamaBin = "/Applications/Ollama.app/Contents/Resources/ollama";

  # Largest offered window across all variants; the server default (see
  # OLLAMA_CONTEXT_LENGTH).
  maxCtx = lib.foldl' (a: v: if v.context > a then v.context else a) 0 registry.variants;

  # Distinct base models to ensure are pulled before creating variants.
  bases = lib.unique (map (v: v.base) registry.variants);

  # Modelfile pinning num_ctx on top of a base model. Shares the base's blobs,
  # so no re-download.
  mkModelfile = v: pkgs.writeText "${lib.replaceStrings [ ":" ] [ "-" ] v.tag}.Modelfile" ''
    FROM ${v.base}
    PARAMETER num_ctx ${toString v.context}
  '';

  # One-shot bootstrap: wait for the ollama server, ensure the base models are
  # present, then (re)create a num_ctx-pinned tag per (model, context). Cheap +
  # idempotent — variants share their base's blobs.
  ollamaModels = pkgs.writeShellScript "ollama-create-variants" ''
    set -u
    export OLLAMA_HOST=${registry.server.host}
    for _ in $(seq 1 60); do
      ${ollamaBin} list >/dev/null 2>&1 && break
      sleep 2
    done
    ${lib.concatMapStringsSep "\n    "
      (b: "${ollamaBin} pull '${b}'")
      bases}
    ${lib.concatMapStringsSep "\n    "
      (v: "${ollamaBin} create '${v.tag}' -f ${mkModelfile v}")
      registry.variants}
  '';
in
{
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
    "kradalby-llm" = { id = "NCR7O6Z-XRY3NIN-XKHAZOE-2EUNNP5-PZ7H53H-47BK2YF-PDWEMQB-FLC4DQU"; };
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
      ProgramArguments = [ ollamaBin "serve" ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive"; # full GPU/perf, not background-throttled
      EnvironmentVariables = {
        # Serving knobs live in common/models.nix.
        OLLAMA_HOST = registry.server.host;
        OLLAMA_KEEP_ALIVE = registry.server.keepAlive;
        # Default served window for direct base-model calls. opencode only uses
        # the num_ctx-pinned variant tags (ollama-models agent below), which
        # override this; set to the largest offered size so an unpinned call is
        # never truncated. 256K KV for a single 35B model fits 128 GB.
        OLLAMA_CONTEXT_LENGTH = toString maxCtx;
        PATH = "/usr/bin:/bin";
      };
      StandardOutPath = "/Users/kradalby/Library/Logs/ollama.log";
      StandardErrorPath = "/Users/kradalby/Library/Logs/ollama.log";
    };
  };

  # Host-rewrite proxy in front of ollama. tailscale serve forwards the tailnet
  # Host (ollama.dalby.ts.net), which ollama's loopback DNS-rebinding guard
  # rejects with 403. caddy rewrites Host to the loopback upstream
  # (127.0.0.1:11434), which the guard accepts.
  #
  # Must use a Caddyfile, not `caddy reverse-proxy --from http://127.0.0.1:11435`:
  # that CLI form scopes the site to Host 127.0.0.1, so requests carrying the
  # tailnet Host match no route and get an empty 200 before the host-rewrite
  # ever runs. The `:11435` site matches any Host; `bind 127.0.0.1` keeps the
  # listener loopback-only, so the tailnet grant stays the sole access control.
  launchd.user.agents.ollama-proxy = {
    serviceConfig = {
      Label = "ollama-proxy";
      ProgramArguments = [
        "${pkgs.caddy}/bin/caddy"
        "run"
        "--adapter"
        "caddyfile"
        "--config"
        "${pkgs.writeText "ollama-proxy.Caddyfile" ''
          {
            admin off
            auto_https off
          }
          :11435 {
            bind 127.0.0.1
            reverse_proxy 127.0.0.1:11434 {
              header_up Host {upstream_hostport}
            }
          }
        ''}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      StandardOutPath = "/Users/kradalby/Library/Logs/ollama-proxy.log";
      StandardErrorPath = "/Users/kradalby/Library/Logs/ollama-proxy.log";
    };
  };

  # Create the num_ctx-pinned variant tags (from common/models.nix) once the
  # server is up. One-shot per activation; the opencode provider in home/ai.nix
  # references these same tags.
  launchd.user.agents.ollama-models = {
    serviceConfig = {
      Label = "ollama-models";
      ProgramArguments = [ "${ollamaModels}" ];
      RunAtLoad = true;
      StandardOutPath = "/Users/kradalby/Library/Logs/ollama-models.log";
      StandardErrorPath = "/Users/kradalby/Library/Logs/ollama-models.log";
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
      devices = [ "kradalby-llm" ];
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
