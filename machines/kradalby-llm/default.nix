{
  lib,
  config,
  pkgs,
  ...
}: let
  aiConfig = import ../../home/ai.nix;

  # Codex equivalent of the Claude dev-env hook: a PreToolUse hook that wraps
  # every Bash command so it runs inside the per-directory Nix dev env.
  codexDevEnvHook = import ../../pkgs/scripts/codex-nix-dev-env-hook.nix {inherit pkgs;};

  # Codex work config: route through the corp Aperture proxy + its MCP server.
  # Codex only speaks the Responses API (the `chat` wire API was removed). The
  # proxy serves openrouter-backed models (glm/deepseek/qwen/…) over chat
  # completions ONLY, so codex cannot reach them — use opencode for those.
  # Codex is therefore limited to the responses-API models (gpt-5.x).
  codexConfig = {
    model = "gpt-5.5";
    model_provider = "aperture";
    model_providers.aperture = {
      name = "Aperture Proxy";
      base_url = "http://ai.corp.ts.net/v1";
      wire_api = "responses";
    };
    mcp_servers.aperture.url = "http://ai.corp.ts.net/v1/mcp";

    # Run every Bash command inside the per-directory Nix dev env (like Claude).
    # Requires a one-time `/hooks` trust in codex (persisted into the mutable
    # config.toml). features.hooks pins it on.
    features.hooks = true;
    hooks.PreToolUse = [
      {
        matcher = "^Bash$";
        hooks = [
          {
            type = "command";
            command = "${codexDevEnvHook}/bin/codex-nix-dev-env-hook";
            timeout = 30;
          }
        ];
      }
    ];
  };

  # Corp AI proxy: fake auth via apiKeyHelper, inject proxy env, add the
  # aperture MCP server. PATH override is required for standalone HM
  # (see note in home/ai.nix).
  claudeSettings = lib.recursiveUpdate aiConfig.claude {
    apiKeyHelper = "echo '-'";
    env = {
      ANTHROPIC_BASE_URL = "http://ai.corp.ts.net";
      PATH = "${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin";
    };
    mcpServers.aperture = {
      type = "http";
      url = "http://ai.corp.ts.net/v1/mcp";
    };
  };

  # Corp AI proxy: strip auth plugin, point providers + MCP at Aperture.
  # Aperture docs: use http:// (WireGuard handles TLS; https:// breaks) and the
  # placeholder key "-". openrouter is built-in to opencode, so overriding only
  # its baseURL unlocks the whole openrouter catalog (glm/deepseek/qwen/…)
  # through the proxy.
  opencodeSettings =
    lib.recursiveUpdate
    (builtins.removeAttrs aiConfig.opencode ["plugin"])
    {
      provider = {
        anthropic.options = {
          baseURL = "http://ai.corp.ts.net/v1";
          apiKey = "-";
        };
        openai.options = {
          baseURL = "http://ai.corp.ts.net/v1";
          apiKey = "-";
        };
        openrouter.options = {
          baseURL = "http://ai.corp.ts.net/v1";
          apiKey = "-";
        };
      };
      mcp.aperture = {
        type = "remote";
        url = "http://ai.corp.ts.net/v1/mcp";
        enabled = true;
      };
      disabled_providers = ["opencode"];
    };
in {
  imports = [
    ../../home
    ./paseo.nix
  ];

  home.username = "ubuntu";
  home.homeDirectory = "/home/ubuntu";

  # Work machine git config (same pattern as kratail2)
  programs.git.settings.user.email = lib.mkForce "kristoffer@tailscale.com";

  # Use HTTPS for GitHub on this machine (SSH egress not available).
  # mkForce replaces the SSH rewrite from home/git.nix entirely so the
  # "gh:" alias and any SSH github remotes resolve to HTTPS.
  programs.git.settings.url = lib.mkForce {
    "https://github.com/" = {
      insteadOf = ["gh:" "git@github.com:" "ssh://git@github.com/"];
      pushInsteadOf = ["gh:" "git@github.com:" "ssh://git@github.com/"];
    };
  };
  programs.gh.settings.git_protocol = lib.mkForce "https";

  # Override AI tool configs to use corp proxy
  my.mutableJson.opencode.value = lib.mkForce opencodeSettings;
  my.mutableJson.claude-settings.value = lib.mkForce claudeSettings;

  my.packages = {
    userland.enable = false;
    nix.enable = false;
    python.enable = false;
    infra.enable = false;
    media.enable = false;
    ai.opencode = true;
  };

  home.packages = [pkgs.master.codex];

  # codex persists trust (project trust, hook trust) back into config.toml, so
  # it must be writable — a read-only store symlink makes codex fail with
  # "failed to persist config". Seed a mutable copy (codex-diff / codex-reset
  # to inspect / re-adopt the nix version).
  my.mutableJson.codex = {
    target = ".codex/config.toml";
    format = "toml";
    value = codexConfig;
  };
}
