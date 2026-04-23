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
      allow = [];
      deny = [];
      ask = [];
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

    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "~/.claude/hooks/rtk-rewrite.sh";
            }
          ];
        }
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

    autoCompactWindow = 380000;
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
    plugin = ["opencode-claude-auth@latest"];

    permission = {
      # Allow reading from common project/build directories.
      external_directory = {
        "~/go/**" = "allow";
        "~/git/**" = "allow";
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
      "/nix/**" = "deny";
    };
    };
  };
}
