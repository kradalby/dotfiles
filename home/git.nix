{
  pkgs,
  config,
  lib,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
in {
  programs.gh = {
    enable = true;

    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Monokai Extended";
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "Kristoffer Dalby";
        email = "kristoffer@dalby.cc";
      } // lib.optionalAttrs isDarwin {
        signingkey = "~/.ssh/id_ed25519.pub";
      };
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
        gpgsign = isDarwin;
      };

      gpg = lib.mkIf isDarwin {
        format = "ssh";
        ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };

      "gpg \"ssh\"" = lib.mkIf isDarwin {
        allowedSignersFile = "~/.ssh/allowed_signers";
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
