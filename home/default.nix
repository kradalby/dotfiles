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

      SSH_AUTH_SOCK = "/Users/kradalby/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
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
      ".golangci.yaml".source = ../rc/golangci.yaml;
      ".minirc.dfl".source = ../rc/minirc.dfl;
      ".npmrc".source = ../rc/npmrc;
      ".sqliterc".source = ../rc/sqliterc;

      # ".tmux.conf".source = ../rc/tmux.conf;
      ".tmuxinator" = {
        source = ../rc/tmuxinator;
        recursive = true;
      };

      ".ssh/config" = {
        source = ../rc/ssh/config;
      };
      ".ssh/config.d" = {
        source = ../rc/ssh/config.d;
        recursive = true;
      };

      ".ssh/allowed_signers".text = ''
        kristoffer@dalby.cc ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup
        kristoffer@tailscale.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOm0+vlPKTRMQm9teF/bCrTPEDEqs1m+B5kMZtuLKh2rDLYM2uwsLPjNjaIlFQfkUn2vyAqGovyKOVR7Q/Z28yo=
      '';

      ".actrc".text = ''
        --container-daemon-socket unix:///Users/kradalby/.colima/default/docker.sock
        --platform ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
        --platform ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04
        --platform ubuntu-22.04=ghcr.io/catthehacker/ubuntu:act-22.04
        --platform ubuntu-20.04=ghcr.io/catthehacker/ubuntu:act-20.04
      '';

      ".config/zed/settings.json".text = builtins.toJSON (import ./zed.nix);

      ".config/nix/nix.conf".text = ''
        experimental-features = nix-command flakes
      '';

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
    ./go.nix
    ./fish.nix
    ./starship.nix
    ./tmux.nix

    ../pkgs/workstation.nix
    ../pkgs/editor-tooling.nix
  ];
}
