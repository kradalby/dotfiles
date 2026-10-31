{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  aiConfig = import ../../home/ai.nix { inherit config lib; };

  # Codex captures the dev environment at SessionStart.
  codexDevEnvHook = import ../../pkgs/scripts/codex-nix-dev-env-hook.nix { inherit pkgs; };

  # Codex work config: route through the corp Aperture proxy + its MCP server.
  # Codex only speaks the Responses API (the `chat` wire API was removed). The
  # proxy serves openrouter-backed models (glm/deepseek/qwen/…) over chat
  # completions ONLY, so codex cannot reach them — use opencode for those.
  # Codex is therefore limited to the responses-API models (gpt-5.x).
  codexConfig = lib.recursiveUpdate aiConfig.codex {
    model = "gpt-5.5";
    model_provider = "aperture";
    model_providers.aperture = {
      name = "Aperture Proxy";
      base_url = "http://ai.corp.ts.net/v1";
      wire_api = "responses";
    };
    mcp_servers.aperture.url = "http://ai.corp.ts.net/v1/mcp";
  };

  sessionPath = "${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin";

  # Corp AI proxy: fake auth via apiKeyHelper and inject proxy env.
  # PATH override is required for standalone HM
  # (see note in home/ai.nix).
  claudeSettings = lib.recursiveUpdate aiConfig.claude {
    apiKeyHelper = "echo '-'";
    env = {
      ANTHROPIC_BASE_URL = "http://ai.corp.ts.net";
      PATH = sessionPath;
    };
  };

  # OpenCode, Hermes and Pi start on this model. Each agent discovers the rest
  # of Aperture's catalog from /v1/models at runtime.
  defaultModel = "openai/gpt-5.6-sol";
in
{
  imports = [
    ../../home
    ../../home/herdr.nix
  ];

  # This box runs codex too, so add its state hook alongside claude/opencode.
  my.herdr.integrations = [
    "claude"
    "codex"
    "opencode"
    "hermes"
    "pi"
  ];

  services.rex = {
    enable = true;
    # Sessions inherit the server's environment.
    environment.PATH = sessionPath;
    # Work tailnet, through this VM's tailscaled. Admits only the node's owner.
    extraListen = [ "tailnet://:7297" ];
    # Personal tailnet, through Rex's own node. The tag keeps a node key copied
    # from this work VM from inheriting group:kradalby's wildcard grant.
    tailscale = {
      enable = true;
      hostname = "kradalby-llm-rex";
      allowTailnetMembers = true;
      advertiseTags = [ "tag:rex" ];
    };
  };

  home.username = "ubuntu";
  home.homeDirectory = "/home/ubuntu";

  # Work machine git config (same pattern as kratail2)
  programs.git.settings.user.email = lib.mkForce "kristoffer@tailscale.com";

  # Use HTTPS for GitHub on this machine (SSH egress not available).
  # mkForce replaces the SSH rewrite from home/git.nix entirely so the
  # "gh:" alias and any SSH github remotes resolve to HTTPS.
  programs.git.settings.url = lib.mkForce {
    "https://github.com/" = {
      insteadOf = [
        "gh:"
        "git@github.com:"
        "ssh://git@github.com/"
      ];
      pushInsteadOf = [
        "gh:"
        "git@github.com:"
        "ssh://git@github.com/"
      ];
    };
  };
  programs.gh.settings.git_protocol = lib.mkForce "https";

  my.mcp.work = true;
  my.claudeMcpServers.aperture = {
    type = "http";
    url = "http://ai.corp.ts.net/v1/mcp";
  };

  # mkForce swaps the shared opencode seed for the Aperture one below.
  my.mutableJson = lib.mkForce {
    claude-settings = {
      target = ".claude/settings.json";
      value = claudeSettings;
    };
    codex = {
      target = ".codex/config.toml";
      format = "toml";
      value = codexConfig;
    };
    codex-hooks = {
      target = ".codex/hooks.json";
      value = aiConfig.codexHooks;
    };
    opencode = {
      target = ".config/opencode/opencode.json";
      value = {
        "$schema" = "https://opencode.ai/config.json";
        inherit (aiConfig.opencode) permission;
        # aperture-models.js adds the Aperture provider and its models.
        enabled_providers = [ "aperture-openai-compatible" ];
        model = "aperture-openai-compatible/${defaultModel}";
        # home/mcp.nix merges the shared servers on every activation.
        mcp.aperture = {
          type = "remote";
          url = "http://ai.corp.ts.net/v1/mcp";
        };
      };
    };
    # herdr installs its TUI plugin only into an existing cli.json.
    opencodeCli = {
      target = ".config/opencode/cli.json";
      value."$schema" = "https://opencode.ai/v2/cli.json";
    };
    hermes = {
      target = ".hermes/config.yaml";
      format = "yaml";
      value = {
        # Keep in sync with hermes_cli/config_defaults.py in the locked input.
        _config_version = 52;
        plugins.enabled = [ "herdr-agent-state" ];
        skills.external_dirs = [ "~/.agents/skills" ];
        model = {
          default = defaultModel;
          provider = "custom:aperture-completions";
        };
        # No models list: Hermes discovers them from /v1/models.
        providers.aperture-completions = {
          api = "http://ai.corp.ts.net/v1";
          api_key = "no-key-required";
          transport = "chat_completions";
        };
        mcp_servers.aperture.url = "http://ai.corp.ts.net/v1/mcp";
      };
    };
    pi-settings = {
      target = ".pi/agent/settings.json";
      value = {
        # The extension names providers after Aperture's backing routes.
        defaultProvider = "vercel-ent-zdr";
        inherit defaultModel;
      };
    };
  };

  my.packages = {
    userland.enable = false;
    nix.enable = false;
    python.enable = false;
    infra.enable = false;
    media.enable = false;
    ai.opencode = true;
  };

  # userland.enable is off here, which drops neovim and tmux (both live in
  # bundles this host disables). $EDITOR and the vim→nvim abbrevs need nvim.
  home.packages = [
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal
    pkgs.master.codex
    # Stable lags the extension API (Pi 1.x).
    pkgs.master.pi-coding-agent
    pkgs.neovim
    pkgs.tmux

    # no setec here; stub keeps direnv's secret_env quiet
    (pkgs.writeShellScriptBin "secret-env" "")
  ];

  # No NixOS module here to write /etc/tmux.conf, so use the XDG path.
  xdg.configFile."tmux/tmux.conf".text = import ../../common/tmux-conf.nix { inherit pkgs lib; };

  xdg.configFile."opencode/plugin/aperture-models.js".source =
    ../../pkgs/scripts/opencode-aperture-models.js;
  # Pi loads the directory through its package.json `pi.extensions` entry.
  home.file.".pi/agent/extensions/aperture-models".source = inputs.pi-aperture-models;

  # Keep the path in mutable config.toml stable across rebuilds and GC. The
  # symlink target changes with Home Manager, without invalidating hook trust.
  home.file.".codex/hooks/nix-dev-env.sh".source = "${codexDevEnvHook}/bin/codex-nix-dev-env-hook";
  home.file.".codex/hooks/session-env.sh".source = ../../pkgs/scripts/codex-session-env.sh;
}
