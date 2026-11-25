# Base AI tool configurations shared across all hosts.
#
# Machine-specific overrides (e.g. corp proxy, custom PATH) should
# import this file and apply lib.recursiveUpdate on top of the
# base attrsets. The shared home/default.nix serialises these to
# JSON via builtins.toJSON and writes them into home.file entries;
# machine configs can lib.mkForce those entries to substitute their
# own merged version.
{
  config,
  lib,
}:
let
  # Served by home.ldn (machines/home.ldn/picnic-mcp.nix). http: the VIP does
  # not terminate TLS.
  picnicMcp = "http://picnic-mcp.dalby.ts.net/mcp";
  grafanaMcp = "http://grafana-mcp.dalby.ts.net/mcp";
  # Both live on the personal tailnet, which work hosts must not reach.
  personal = !config.my.mcp.work;
  superlogicalMcp = "https://www.superlogical.com/rex/community-mcp";
  # Codex keeps existing registrations; the profile path survives package upgrades.
  nixosMcp = "${config.home.profileDirectory}/bin/mcp-nixos";
  # Wrapper from home/cooklang.nix, which bakes in the recipe root.
  cookMcp = "${config.home.profileDirectory}/bin/cook-mcp";
  cook = config.my.cooklang.recipes != null;
  mailMcp = "${config.home.profileDirectory}/bin/apple-mailbox-mcp";
  # Hides the mail tools from every agent; the mail-triage agent's own rules
  # come later and re-allow them.
  mailDeny = {
    action = "mail_*";
    resource = "*";
    effect = "deny";
  };
in
{
  # Claude Code ignores mcpServers in settings.json; it reads user-scope
  # servers from ~/.claude.json, which home/mcp.nix merges these into.
  claudeMcpServers =
    lib.optionalAttrs personal {
      picnic = {
        type = "http";
        url = picnicMcp;
      };
      grafana = {
        type = "http";
        url = grafanaMcp;
      };
    }
    // lib.optionalAttrs config.my.packages.ai.enable {
      nixos = {
        type = "stdio";
        command = nixosMcp;
        args = [ ];
      };
    }
    // lib.optionalAttrs cook {
      cook = {
        type = "stdio";
        command = cookMcp;
        args = [ ];
      };
    }
    // {
      superlogical = {
        type = "http";
        url = superlogicalMcp;
      };
    };

  claude = {
    permissions = {
      allow = [ ];
      deny = [ ];
      # Prompt, not deny: pushing is fine once explicitly asked.
      ask = [ "Bash(git push:*)" ];
      defaultMode = "auto";
    };

    # PATH covers NixOS, nix-darwin, and Homebrew locations.
    # Standalone Home Manager hosts (e.g. kradalby-llm) should
    # override with config.home.profileDirectory/bin.
    env = {
      CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";

      # Pairs with ponytail: ponytail what gets built, caveman how it reads.
      CAVEMAN_DEFAULT_MODE = "full";

      PATH = builtins.concatStringsSep ":" [
        "/run/wrappers/bin"
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

    alwaysThinkingEnabled = true;
    effortLevel = "high";

    # The non-interactive Bash tool never sources the shell rc, so direnv
    # and `nix develop` never activate. This hook runs nix-dev-env.sh (see
    # home/default.nix) on session start, which loads per-directory dev envs
    # via CLAUDE_ENV_FILE: direnv (.envrc) primary, `nix print-dev-env` for a
    # flake.nix as fallback.
    #
    # Re-run on directory changes so Bash follows the active project's dev env.
    # CwdChanged is supported by Claude Code >=2.1.246 and exposes both
    # new_cwd and CLAUDE_ENV_FILE to command hooks.
    hooks = rec {
      SessionStart = [
        {
          hooks = [
            {
              type = "command";
              command = ''bash "$HOME/.claude/hooks/nix-dev-env.sh" || true'';
            }
          ];
        }
      ];
      CwdChanged = SessionStart;

      # Plain goimports (no -local): repos whose linters use no local prefix
      # would flag a split import group. Parse failures are left for the
      # repo's own toolchain to report.
      PostToolUse = [
        {
          matcher = "Edit|MultiEdit|Write";
          hooks = [
            {
              type = "command";
              command = ''f=$(jq -r '.tool_input.file_path // empty'); case "$f" in *.go) goimports -w "$f" 2>/dev/null ;; esac; true'';
            }
          ];
        }
      ];
    };

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

    # Remote ollama on kratail2, served over the kradalby.no tailnet
    # (svc:ollama -> tailscale serve -> caddy -> 127.0.0.1:11434). `ollama` is
    # a built-in provider, so only the endpoint is set; opencode also discovers
    # the served tags itself. Models + context sizes come from the shared
    # registry; the matching num_ctx-pinned tags are created on kratail2 (see
    # the ollama-models agent there). Verify the live set:
    #   curl -s http://ollama.dalby.ts.net/v1/models | jq -r '.data[].id'
    providers.ollama =
      let
        # Shared with machines/kratail2 so the model list and the served
        # num_ctx tags can never drift.
        registry = import ../common/models.nix;

        # opencode entry for one (model, context) variant. Behaviour comes from
        # the registry; opencode packs to limit.context and ollama serves that
        # variant's num_ctx, so the two match by construction. local => zero cost.
        mkModel = v: {
          name = "${v.label} @ ${toString (v.context / 1024)}k";
          # Unset, opencode assumes image input.
          capabilities = {
            inherit (v) tools;
            input = [ "text" ] ++ lib.optional v.vision "image";
            output = [ "text" ];
          };
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
        name = "Ollama (kratail2)";
        settings.baseURL = "http://ollama.dalby.ts.net/v1";
        # One entry per (model, context); keys are the ollama variant tags.
        models = builtins.listToAttrs (
          map (v: {
            name = v.tag;
            value = mkModel v;
          }) registry.variants
        );
      };

    mcp.servers =
      # No picnic: opencode serve opens one MCP session per directory and
      # retries 429s, which drains picnic-mcp's single shared rate limit.
      lib.optionalAttrs personal {
        grafana = {
          type = "remote";
          url = grafanaMcp;
        };
      }
      // lib.optionalAttrs config.my.packages.ai.enable {
        nixos = {
          type = "local";
          command = [ nixosMcp ];
        };
      }
      // lib.optionalAttrs cook {
        cook = {
          type = "local";
          command = [ cookMcp ];
        };
      }
      // lib.optionalAttrs config.my.mail.triage.enable {
        mail = {
          type = "local";
          command = [ mailMcp ];
          # Upstream sends to anyone by default; this limits it to the owner.
          environment.EMAIL_MCP_SEND_ALLOW_ALL = "0";
        };
      }
      // {
        superlogical = {
          type = "remote";
          url = superlogicalMcp;
        };
      };

    # Deny edits outside the working tree — these directories are read-only
    # reference material, not targets for changes. Reads need no rule: paths
    # outside the project are allowed by default.
    permissions =
      map
        (resource: {
          action = "edit";
          inherit resource;
          effect = "deny";
        })
        [
          "~/go/*"
          "~/git/*"
          "~/worktrees/*"
          "/nix/*"
        ]
      ++ lib.optional config.my.mail.triage.enable mailDeny;
  };

  # Codex has no model/provider block here on purpose: signed-in codex picks
  # its own default, and pinning one would drift.
  #
  # Only the hooks feature flag lives in config.toml. Codex reads hooks from both
  # config.toml and hooks.json and warns when definitions are split across the
  # two, so hook definitions go to hooks.json instead (see codexHooks).
  codex = {
    # Approve for me: sandboxed, escalations go to the auto reviewer.
    default_permissions = ":workspace";
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    daybreak = true;
    features.hooks = true;
    shell_environment_policy.set.BASH_ENV = "$HOME/.codex/hooks/session-env.sh";
    mcp_servers =
      lib.optionalAttrs personal {
        picnic.url = picnicMcp;
        grafana.url = grafanaMcp;
      }
      // lib.optionalAttrs config.my.packages.ai.enable {
        nixos.command = nixosMcp;
      }
      // lib.optionalAttrs cook {
        cook.command = cookMcp;
      }
      // {
        superlogical.url = superlogicalMcp;
      };
  };

  # ~/.codex/hooks.json — the single hook layer. Other tools may merge their
  # own entries into this file, and the migration keeps them. Codex still needs a one-time `/hooks` trust per entry, which it
  # records in config.toml.
  #
  # Capture the dev env once per thread, including phone-initiated resumes.
  # Bash reads it through BASH_ENV without changing the displayed command.
  inherit mailDeny;

  codexHooks = {
    hooks.SessionStart = [
      {
        matcher = "^(startup|resume|clear|fork)$";
        hooks = [
          {
            type = "command";
            command = ''"$HOME/.codex/hooks/nix-dev-env.sh"'';
            timeout = 120;
          }
        ];
      }
    ];
  };
}
