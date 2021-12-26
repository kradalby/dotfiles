{ config, pkgs, lib, ... }: {
  # Available options
  # https://nix-community.github.io/home-manager/options.html


  home = {

    sessionPath = [
      # "/etc/profiles/per-user/$USER/bin"
      "$HOME/bin"
      "$HOME/.bin"
      "$HOME/git/dotfiles/bin"
      "$HOME/.cargo/bin"
      "$HOME/.local/bin"
      "$HOME/.nixpkgs/bin"
    ];

    sessionVariables = {
      LANG = "en_US.UTF-8";
      EDITOR = "nvim";

      # Apparently nix-direnv or direnv sets this to something weird
      GNUPGHOME = "~/.gnupg";
      GPG_FINGERPRINT = "09F62DC067465735";

      TMPDIR = "/tmp";

      ANSIBLE_HOST_KEY_CHECKING = "False";
      ANSIBLE_CONFIG = "$HOME/.ansible.cfg";
      GO111MODULE = "on";

      TF_X_HELM_MANIFEST = 1;

      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    };

    packages = [
    ];


    file = {
      ".alacritty.yml".source = ../rc/alacritty.yml;
      ".ansible.cfg".source = ../rc/ansible.cfg;
      ".editorconfig".source = ../rc/editorconfig;
      ".eslintrc.json".source = ../rc/eslintrc.json;
      ".golangci.yaml".source = ../rc/golangci.yaml;
      ".minirc.dfl".source = ../rc/minirc.dfl;
      ".npmrc".source = ../rc/npmrc;

      ".tmux.conf".source = ../rc/tmux.conf;
      ".tmuxinator" = {
        source = ../rc/tmuxinator;
        recursive = true;
      };

      ".config/nvim" = {
        source = ../rc/nvim;
        recursive = true;
        # onChange = ''
        #   mkdir -p ~/logs
        #   nvim --headless -c "autocmd User PackerComplete quitall" -c "PackerSync" > ~/logs/nvim_packer.log 2>&1
        #   nvim --headless -c "lua require('tools').install_servers()" -c "quitall" > ~/logs/nvim_lsp.log 2>&1
        # '';
      };

      ".ssh/config" = {
        source = ../rc/ssh/config;
      };
      ".ssh/config.d" = {
        source = ../rc/ssh/config.d;
        recursive = true;
      };

      ".config/nix/nix.conf".text = ''
        experimental-features = nix-command flakes
      '';
    };
  };

  programs = {
    home-manager.enable = true;

    bat = {
      enable = true;
      config.theme = "Monokai Extended";
    };

    jq.enable = true;

    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    htop.enable = true;
    aria2.enable = true;
    gpg.enable = true;

    exa.enable = true;

    less.enable = true;
    lesspipe.enable = true;
    man.enable = true;

    # TODO
    # neovim.enable = true;
    # tmux.enable = true;
  };

  imports = [
    ./git.nix
    ./go.nix
    ./fish.nix
    ./starship.nix
    ./kitty.nix

    ../pkgs/macos.nix
    ../pkgs/workstation.nix
    ../pkgs/dev.nix
    ../pkgs/common.nix
  ];
}

