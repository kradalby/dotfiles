{
  pkgs,
  config,
  ...
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
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Monokai Extended";
      };
    };
    lfs.enable = true;

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
      github = {user = "kradalby";};

      commit = {
        gpgsign = config.programs.git.extraConfig.user.signingkey != "";
      };

      gpg = {
        format = "ssh";
        ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };

      "gpg \"ssh\"" = {
        allowedSignersFile = "~/.ssh/allowed_signers";
      };

      user = {
        signingkey = "~/.ssh/id_ed25519.pub";
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
