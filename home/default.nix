{
  config,
  pkgs,
  lib,
  ...
}: let
  agentsBase = builtins.readFile ../rc/AGENTS.md;
  agentsExtra = config.my.agents.extraInstructions;
  agentsContent = agentsBase + lib.optionalString (agentsExtra != "") ("\n" + agentsExtra);

  # Hook script that makes Claude Code's non-interactive Bash tool adopt
  # per-directory dev envs (direnv primary, `nix print-dev-env` fallback).
  # Wired into settings.json hooks via home/ai.nix.
  nixDevEnvHook = import ../pkgs/scripts/nix-dev-env.nix {inherit pkgs;};
in {
  # Available options
  # https://nix-community.github.io/home-manager/options.html

  options.my.agents.extraInstructions = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Per-host markdown appended to the shared AGENTS.md/CLAUDE.md.";
  };

  imports = [
    ./git.nix
    ./fish.nix
    ./starship.nix
    ./ssh.nix

    ../modules/claude-code

    ./mutable-json.nix

    ../pkgs/home-packages.nix
  ];

  # settings.json/opencode.json are written by their clients at runtime, so
  # they cannot be read-only store symlinks. Deploy mutable copies + diff
  # helpers (claude-settings-diff/reset, opencode-diff/reset) instead.
  config.my.mutableJson = {
    claude-settings = {
      target = ".claude/settings.json";
      value = (import ./ai.nix).claude;
    };
    opencode = {
      target = ".config/opencode/opencode.json";
      value = (import ./ai.nix).opencode;
    };
  };

  config.home = {
    stateVersion = "22.05";

    sessionPath = [
      # I dont think this should be needed, but it seems
      # to disappair...
      "/run/current-system/sw/bin"

      # This is a workaround as the path is not
      # available to mosh unless its loaded here.
      "/usr/local/bin"

      # On M Macs, homebrew is moved
      (lib.mkIf (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64) "/opt/homebrew/bin")

      # "/etc/profiles/per-user/$USER/bin"
      "$HOME/bin"
      "$HOME/.bin"
      "$HOME/.cargo/bin"
      "$HOME/.local/bin"
      "$HOME/.nixpkgs/bin"

      # Load user profiles bin
      # "/etc/profiles/per-user/$USER/bin"
    ];

    sessionVariables = {
      EDITOR = "nvim";

      # Apparently nix-direnv or direnv sets this to something weird
      # GNUPGHOME = "~/.gnupg";
      # GPG_FINGERPRINT = "09F62DC067465735";

      TMPDIR = "/tmp";

      ANSIBLE_HOST_KEY_CHECKING = "False";
      ANSIBLE_CONFIG = "$HOME/.ansible.cfg";

      TF_X_HELM_MANIFEST = 1;

      GIT_SSH_COMMAND = "ssh";

      # Disable Claude Code's adaptive thinking heuristic so every turn
      # gets the full thinking budget instead of being shortchanged.
      CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1";
    };

    language = {
      base = "en_US.UTF-8";
      ctype = "";
    };

    file = {
      ".ansible.cfg".source = ../rc/ansible.cfg;
      ".editorconfig".source = ../rc/editorconfig;
      ".eslintrc.json".source = ../rc/eslintrc.json;
      ".minirc.dfl".source = ../rc/minirc.dfl;
      ".npmrc".source = ../rc/npmrc;
      ".sqliterc".source = ../rc/sqliterc;

      ".ssh/allowed_signers".text = ''
        kristoffer@dalby.cc ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup
        kristoffer@dalby.cc ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJmukT03vff7EvEQb57NYPvM4TgCVLYcRq4SxE+YOSGx kradalby@dev
      '';

      ".config/ghostty/config".source = ../rc/ghostty;
      # Global agent instructions — agents walk up from cwd, so
      # placing this in $HOME acts as a catch-all for repos that
      # don't ship their own AGENTS.md.
      "AGENTS.md".text = agentsContent;
      ".config/opencode/AGENTS.md".text = agentsContent;
      ".config/opencode/commands".source = ../rc/claude/commands;

      ".claude/commands" = {
        source = ../rc/claude/commands;
        recursive = true;
      };
      ".claude/CLAUDE.md".text = agentsContent;

      # Stable path for the per-directory dev-env hook. A symlink (not a
      # store path inlined into the seeded-once settings.json) so it tracks
      # the current build on every switch. Hooks registered in home/ai.nix.
      ".claude/hooks/nix-dev-env.sh".source = "${nixDevEnvHook}/bin/nix-dev-env";

      # opencode equivalent of the Claude dev-env hook: a shell.env plugin that
      # injects the per-directory Nix dev env into every shell command. Auto-
      # discovered from the plugin dir; no opencode.json entry needed.
      ".config/opencode/plugin/nix-dev-env.js".source =
        ../pkgs/scripts/opencode-nix-dev-env.js;

      ".config/nix/nix.conf".text = ''
        experimental-features = nix-command flakes
      '';

      # rnb (remote nix builder) reads its registry from here; single
      # source of truth is common/rnb-builders.nix.
      ".config/rnb/builders.json".text =
        builtins.toJSON (import ../common/rnb-builders.nix);

      ".finicky.js" = lib.mkIf pkgs.stdenv.isDarwin {source = ../rc/finicky.js;};

      ".vale.ini".text = ''
        # This goes in a file named either `.vale.ini` or `_vale.ini`.
        StylesPath = styles
        MinAlertLevel = suggestion

        # External packages
        Packages = Google, Readability, alex, proselint
        # Only Markdown and .txt files; change to whatever you're using.
        [*.{md,txt}]
        # List of styles to load.
        BasedOnStyles = alex, proselint
      '';
    };
  };

  config.programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
      };
      # secret_env [-v] — load `VAR  PATH` lines (resolved in parallel via
      # secret-env) into the environment; fails the .envrc if any secret is
      # missing. -v traces resolution (use it in your own repos, not public
      # ones). Usage:
      #   secret_env -v <<'EOF'
      #   TF_VAR_x  infra/x
      #   EOF
      stdlib = ''
        secret_env() {
          local env
          env=$(secret-env "$@") || { log_error "secret_env: secret load failed"; return 1; }
          eval "$env"
        }
      '';
    };

    bat = {
      enable = true;
      config.theme = "Monokai Extended";
    };

    jq.enable = true;

    fzf = {
      enable = true;
      enableFishIntegration = true;

      changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d";
      defaultCommand = "${pkgs.fd}/bin/fd --type f --strip-cwd-prefix";

      fileWidgetOptions = [
        "--preview '${pkgs.bat}/bin/bat -n --color=always {}'"
        "--bind 'ctrl-/:change-preview-window(down|hidden|)'"
        "--tmux center,85%"
      ];

      tmux = {
        enableShellIntegration = true;
      };
    };

    htop.enable = true;
    aria2.enable = true;
    gpg.enable = true;

    less.enable = true;
    lesspipe.enable = true;
    man.enable = true;
  };
}
