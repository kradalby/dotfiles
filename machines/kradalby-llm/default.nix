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

  # Corp AI proxy: fake auth via apiKeyHelper and inject proxy env.
  # PATH override is required for standalone HM
  # (see note in home/ai.nix).
  claudeSettings = lib.recursiveUpdate aiConfig.claude {
    apiKeyHelper = "echo '-'";
    env = {
      ANTHROPIC_BASE_URL = "http://ai.corp.ts.net";
      PATH = "${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin";
    };
  };

  # Both tools start on this model; the sync refuses a catalog that lacks it.
  defaultModel = "openai/gpt-5.6-sol";

  # Aperture owns the remote catalog. These overlays contain only policy that is
  # local to this host and are reapplied whenever that catalog is refreshed.
  opencodeOverlay = {
    provider.ollama = aiConfig.opencode.provider.ollama;
    permission = aiConfig.opencode.permission;
    mcp.aperture.enabled = true;
    mcp.nixos = aiConfig.opencode.mcp.nixos;
    model = "aperture-openai-compatible/${defaultModel}";
  };

  hermesOverlay = {
    # Keep in sync with hermes_cli/config_defaults.py in the locked input.
    _config_version = 52;
    # Herdr installs the plugin files; keep enablement across manual refreshes.
    plugins.enabled = [ "herdr-agent-state" ];
    skills.external_dirs = [ "~/.agents/skills" ];
    model = {
      default = defaultModel;
      provider = "custom:aperture-completions";
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

  my.claudeMcpServers.aperture = {
    type = "http";
    url = "http://ai.corp.ts.net/v1/mcp";
  };

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
    codex-hooks = {
      target = ".codex/hooks.json";
      value = aiConfig.codexHooks;
    };
    # Aperture does not own the TUI settings; herdr needs them seeded.
    opencodeCli = {
      target = ".config/opencode/cli.json";
      value."$schema" = "https://opencode.ai/v2/cli.json";
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
  home.file.".codex/hooks/session-env.sh".source = ../../pkgs/scripts/codex-session-env.sh;

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
