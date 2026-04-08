{
  config,
  pkgs,
  lib,
  ...
}: {
  # Available options
  # https://nix-community.github.io/home-manager/options.html

  home = {
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
      "$HOME/git/dotfiles/bin"
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
      ".alacritty.yml".source = ../rc/alacritty.yml;
      ".ansible.cfg".source = ../rc/ansible.cfg;
      ".editorconfig".source = ../rc/editorconfig;
      ".eslintrc.json".source = ../rc/eslintrc.json;
      ".minirc.dfl".source = ../rc/minirc.dfl;
      ".npmrc".source = ../rc/npmrc;
      ".sqliterc".source = ../rc/sqliterc;

      # ".tmux.conf".source = ../rc/tmux.conf;
      ".tmuxinator" = {
        source = ../rc/tmuxinator;
        recursive = true;
      };

      ".ssh/allowed_signers".text = ''
        kristoffer@dalby.cc ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup
        kristoffer@dalby.cc ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJmukT03vff7EvEQb57NYPvM4TgCVLYcRq4SxE+YOSGx kradalby@dev
      '';

      ".config/ghostty/config".source = ../rc/ghostty;
      ".config/opencode/opencode.json".source = ../rc/opencode/opencode.json;
      ".config/opencode/commands".source = ../rc/ai-commands;

      ".claude/commands".source = ../rc/ai-commands;

      ".config/nix/nix.conf".text = ''
        experimental-features = nix-command flakes
      '';

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

  programs = {
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

  imports = [
    ./git.nix
    ./fish.nix
    ./starship.nix
    ./tmux.nix
    ./ssh.nix

    ../pkgs/home-packages.nix
  ];
}
