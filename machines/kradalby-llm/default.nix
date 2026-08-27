{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  aiConfig = import ../../home/ai.nix;

  # Codex equivalent of the Claude dev-env hook: a PreToolUse hook that wraps
  # every Bash command so it runs inside the per-directory Nix dev env.
  codexDevEnvHook = import ../../pkgs/scripts/codex-nix-dev-env-hook.nix { inherit pkgs; };

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
            command = ''"$HOME/.codex/hooks/nix-dev-env.sh"'';
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

  readonlyAgent = model: description: prompt: {
    inherit model description prompt;
    mode = "subagent";
    permission = {
      edit = "deny";
      bash = "deny";
      task = "deny";
    };
  };

  # Aperture owns the remote catalog. This overlay contains only policy that is
  # local to this host and is reapplied whenever that catalog is refreshed.
  opencodeOverlay = {
    provider.ollama = aiConfig.opencode.provider.ollama;
    permission = aiConfig.opencode.permission;
    mcp.aperture.enabled = true;
    default_agent = "frontier";
    agent = {
      frontier = {
        description = "Frontier-model orchestrator that challenges and synthesizes independent reviews";
        mode = "primary";
        model = "aperture-openai/openai/gpt-5.6-sol";
        prompt = ''
          For consequential or ambiguous work, ask the frontier subagents for
          independent analyses in parallel. Require them to challenge the
          assumptions and likely failure modes in the proposed approach, then
          reconcile disagreements and synthesize the best-supported result.
          Use judgement for routine work where fan-out would add no value.
        '';
        permission.task = {
          "*" = "deny";
          "claude-opus" = "allow";
          deepseek = "allow";
          gemini = "allow";
          kimi = "allow";
          glm = "allow";
        };
      };
      claude-opus =
        readonlyAgent "aperture-anthropic/anthropic/claude-opus-5"
          "Independent Claude Opus reviewer for architecture, correctness, and overlooked risks"
          "Analyze independently. Challenge assumptions, identify concrete failure modes, and recommend the strongest approach.";
      deepseek =
        readonlyAgent "aperture-openai-compatible/deepseek/deepseek-v4-pro"
          "Independent DeepSeek reviewer for technical reasoning and implementation details"
          "Develop an independent technical solution. Look for logical gaps, edge cases, and simpler alternatives.";
      gemini =
        readonlyAgent "aperture-openai-compatible/google/gemini-3.7-flash"
          "Independent Gemini reviewer for broad alternatives and missing context"
          "Review from a distinct perspective. Surface missing information, counterexamples, and viable alternatives.";
      kimi =
        readonlyAgent "aperture-openai-compatible/moonshotai/kimi-k3"
          "Independent Kimi reviewer for code, long-context analysis, and integration risks"
          "Inspect the full context independently. Focus on cross-file interactions, integration risks, and concrete corrections.";
      glm =
        readonlyAgent "aperture-openai-compatible/zai/glm-5.3"
          "Independent GLM reviewer for adversarial validation and pragmatic alternatives"
          "Try to disprove the leading approach. Report correctness, security, and operational concerns with actionable fixes.";
    };
  };

  hermesOverlay = {
    # Keep in sync with hermes_cli/config_defaults.py in the locked input.
    _config_version = 39;
    # Herdr installs the plugin files; keep enablement across manual refreshes.
    plugins.enabled = [ "herdr-agent-state" ];
    skills.external_dirs = [ "~/.agents/skills" ];
    model = {
      default = "frontier";
      provider = "moa";
    };
    moa = {
      active_preset = "frontier";
      default_preset = "frontier";
      presets.frontier = {
        enabled = true;
        fanout = "user_turn";
        reference_max_tokens = 600;
        reference_models = [
          {
            provider = "custom:aperture-claude";
            model = "anthropic/claude-opus-5";
            reasoning_effort = "medium";
          }
          {
            provider = "custom:aperture-completions";
            model = "deepseek/deepseek-v4-pro";
            reasoning_effort = "medium";
          }
          {
            provider = "custom:aperture-completions";
            model = "google/gemini-3.7-flash";
            reasoning_effort = "medium";
          }
          {
            provider = "custom:aperture-completions";
            model = "moonshotai/kimi-k3";
            reasoning_effort = "medium";
          }
          {
            provider = "custom:aperture-completions";
            model = "zai/glm-5.3";
            reasoning_effort = "medium";
          }
        ];
        aggregator = {
          provider = "custom:aperture-responses";
          model = "openai/gpt-5.6-sol";
          reasoning_effort = "high";
        };
      };
    };
  };

  apertureAgentConfigSync = import ./aperture-agent-config-sync.nix {
    inherit pkgs opencodeOverlay hermesOverlay;
  };
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

  # OpenCode and Hermes are refreshed from Aperture below. Claude and Codex
  # retain mutable configs because they persist trust and other runtime state.
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
    apertureAgentConfigSync
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal
    pkgs.master.codex
    pkgs.neovim
    pkgs.tmux

    # no setec here; stub keeps direnv's secret_env quiet
    (pkgs.writeShellScriptBin "secret-env" "")
  ];

  # No NixOS module here to write /etc/tmux.conf, so use the XDG path.
  xdg.configFile."tmux/tmux.conf".text = import ../../common/tmux-conf.nix { inherit pkgs lib; };

  # Keep the path in mutable config.toml stable across rebuilds and GC. The
  # symlink target changes with Home Manager, without invalidating hook trust.
  home.file.".codex/hooks/nix-dev-env.sh".source = "${codexDevEnvHook}/bin/codex-nix-dev-env-hook";

  # Keep the generated model catalogs current at the same boundary as the rest
  # of this host's declarative configuration. The command is also on PATH for
  # an explicit refresh between Home Manager activations.
  home.activation.apertureAgentConfig =
    lib.hm.dag.entryBetween
      [ "herdrIntegrations" ]
      [
        "writeBoundary"
        "mutableJson"
      ]
      ''
        run ${apertureAgentConfigSync}/bin/aperture-agent-config-sync
      '';
}
