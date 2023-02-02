{ pkgs
, config
, ...
}: {
  programs.gh = {
    enable = true;

    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
  };

  programs.git = {
    enable = true;
    userName = "Kristoffer Dalby";
    userEmail = "kristoffer@dalby.cc";
    # aliases = {
    #   prettylog = "log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
    # };
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Monokai Extended";
      };
    };

    extraConfig = {
      core = {
        editor = "nvim";
        # If git uses `ssh` from Nix the macOS-specific configuration in
        # `~/.ssh/config` won't be seen as valid
        # https://github.com/NixOS/nixpkgs/issues/15686#issuecomment-865928923
        sshCommand = "/usr/bin/ssh";
      };
      color = {
        ui = true;
      };
      push = {
        default = "simple";
      };
      pull = {
        rebase = true;
      };
      init = {
        defaultBranch = "main";
      };

      fetch = {
        prune = true;
      };

      # Clone git repos with URLs like "gh:alexpearce/dotfiles"
      url."git@github.com:" = {
        insteadOf = "gh:";
        pushInsteadOf = "gh:";
      };

      commit = {
        gpgsign = config.programs.git.extraConfig.user.signingkey != "";
      };

      gpg = {
        format = "ssh";
      };

      "gpg \"ssh\"" = {
        allowedSignersFile = "~/.ssh/allowed_signers";
      };

      user = {
        signingkey = "";
      };
    };

    ignores = [
      ".*.swp"
      ".bundle"
      "vendor/bundle"
      ".DS_Store"
      "Icon"
      "*.pyc"
      ".envrc"
      ".direnv"
      "environment.yaml"
    ];
  };
}
