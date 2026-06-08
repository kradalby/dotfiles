# Base AI tool configurations shared across all hosts.
#
# Machine-specific overrides (e.g. corp proxy, custom PATH) should
# import this file and apply lib.recursiveUpdate on top of the
# base attrsets. The shared home/default.nix serialises these to
# JSON via builtins.toJSON and writes them into home.file entries;
# machine configs can lib.mkForce those entries to substitute their
# own merged version.
{
  claude = {
    permissions = {
      allow = [ ];
      deny = [ ];
      ask = [ ];
      defaultMode = "bypassPermissions";
    };

    # PATH covers NixOS, nix-darwin, and Homebrew locations.
    # Standalone Home Manager hosts (e.g. kradalby-llm) should
    # override with config.home.profileDirectory/bin.
    env = {
      PATH = builtins.concatStringsSep ":" [
        "/etc/profiles/per-user/kradalby/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
    };

    enabledPlugins = {
      "gopls-lsp@claude-plugins-official" = true;
      "code-simplifier@claude-plugins-official" = true;
      "ui-ux-pro-max@ui-ux-pro-max-skill" = true;
      "frontend-design@claude-plugins-official" = true;
      "superpowers@claude-plugins-official" = true;
      "code-review@claude-plugins-official" = true;
      "github@claude-plugins-official" = true;
      "frontend-design@claude-code-plugins" = true;
      "playwright@claude-plugins-official" = true;
      "caveman@caveman" = true;
    };

    extraKnownMarketplaces = {
      ui-ux-pro-max-skill.source = {
        source = "github";
        repo = "nextlevelbuilder/ui-ux-pro-max-skill";
      };
      claude-code-plugins.source = {
        source = "github";
        repo = "anthropics/claude-code";
      };
      caveman.source = {
        source = "github";
        repo = "JuliusBrussee/caveman";
      };
    };

    alwaysThinkingEnabled = true;
    effortLevel = "high";
    skipDangerousModePermissionPrompt = true;

    # Status bar: renders a unicode progress bar showing context
    # window usage with a marker at the 38% auto-compact threshold.
    statusLine = {
      type = "command";
      command = builtins.concatStringsSep " " [
        "input=$(cat);"
        "used=$(echo \"$input\" | jq -r '.context_window.used_percentage // empty');"
        "[ -z \"$used\" ] && exit 0;"
        "filled=$(printf '%.0f' \"$used\");"
        "total=20;"
        "marker=$((38 * total / 100));"
        "bars=$((filled * total / 100));"
        "bar='';"
        "i=0;"
        "while [ $i -lt $total ]; do"
        "if [ $i -eq $marker ]; then"
        "if [ $i -lt $bars ]; then bar=\"\${bar}▓\"; else bar=\"\${bar}│\"; fi;"
        "elif [ $i -lt $bars ]; then bar=\"\${bar}█\"; else bar=\"\${bar}░\"; fi;"
        "i=$((i+1)); done;"
        "printf 'Context [%s] %s%% (compact@38%%)' \"$bar\" \"$filled\""
      ];
    };
  };

  opencode = {
    "$schema" = "https://opencode.ai/config.json";

    # Auth plugin for personal use; corp-proxy hosts should strip
    # this via builtins.removeAttrs and set provider directly.
    plugin = [ "opencode-claude-auth@latest" ];

    # Remote ollama on kratail2, served over the kradalby.no tailnet
    # (svc:ollama -> tailscale serve -> caddy -> 127.0.0.1:11434). Speaks the
    # OpenAI-compatible API at /v1. Models + context sizes come from the shared
    # registry; the matching num_ctx-pinned tags are created on kratail2 (see
    # the ollama-models agent there). Verify the live set:
    #   curl -s http://ollama.dalby.ts.net/v1/models | jq -r '.data[].id'
    provider.ollama =
      let
        # Shared with machines/kratail2 so the model list and the served
        # num_ctx tags can never drift.
        registry = import ../common/models.nix;

        # opencode entry for one (model, context) variant. Behaviour comes from
        # the registry; opencode packs to limit.context and ollama serves that
        # variant's num_ctx, so the two match by construction. local => zero cost.
        mkModel = v: {
          name = "${v.label} @ ${toString (v.context / 1024)}k";
          tool_call = v.tools;
          reasoning = v.reasoning;
          attachment = v.vision;
          limit = {
            inherit (v) context output;
          };
          cost = {
            input = 0;
            output = 0;
          };
        };
      in
      {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (kratail2)";
        options = {
          baseURL = "http://ollama.dalby.ts.net/v1";
          apiKey = "ollama"; # ignored by ollama; the OpenAI SDK requires one
        };
        # One entry per (model, context); keys are the ollama variant tags.
        models = builtins.listToAttrs (
          map
            (v: {
              name = v.tag;
              value = mkModel v;
            })
            registry.variants
        );
      };

    permission = {
      # Allow reading from common project/build directories.
      external_directory = {
        "~/go/**" = "allow";
        "~/git/**" = "allow";
        "~/worktrees/**" = "allow";
        "/nix/**" = "allow";
        "/tmp/**" = "allow";
        # macOS maps /tmp to /private/tmp.
        "/private/tmp/**" = "allow";
        # Claude Code stores session data, CLAUDE.md, etc.
        "~/.claude/**" = "allow";
      };
      # Deny edits outside the working tree — these directories
      # are read-only reference material, not targets for changes.
      edit = {
        "~/go/**" = "deny";
        "~/git/**" = "deny";
        "~/worktrees/**" = "deny";
        "/nix/**" = "deny";
      };
    };
  };
}
