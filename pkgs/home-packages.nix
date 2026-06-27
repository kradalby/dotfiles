{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.packages;
  tom = import ./scripts/tom.nix {inherit pkgs;};
  tmp-cleanup = import ./scripts/tmp-cleanup.nix {inherit pkgs;};
in {
  options.my.packages = {
    userland.enable = (lib.mkEnableOption "Interactive userland (editor + shell tools)") // {default = true;};

    go.enable = (lib.mkEnableOption "Go development") // {default = true;};
    nix.enable = (lib.mkEnableOption "Nix tooling") // {default = true;};
    web.enable = (lib.mkEnableOption "Web/JS/TS development") // {default = true;};
    python.enable = (lib.mkEnableOption "Python development") // {default = true;};
    shell.enable = (lib.mkEnableOption "Shell tools") // {default = true;};

    editor.enable = (lib.mkEnableOption "General editor support") // {default = true;};
    infra.enable = (lib.mkEnableOption "Infrastructure and ops") // {default = true;};
    media.enable = (lib.mkEnableOption "Media and data tools") // {default = true;};
    ai.enable = (lib.mkEnableOption "AI coding assistants") // {default = true;};
    ai.opencode = (lib.mkEnableOption "opencode AI assistant") // {default = true;};
  };

  config = lib.mkMerge [
    # Core packages (always installed)
    {
      home.packages =
        (with pkgs; [
          eza
          viddy
          prettyping
          entr
          eb
          (git-absorb.overrideAttrs (old: rec {
            version = "3a1148ea2df3ca41cb69df8848f99d25e66dc0b5";
            src = pkgs.fetchFromGitHub {
              owner = "tummychow";
              repo = "git-absorb";
              rev = version;
              hash = "sha256-CrpLWDHSnT2PgbLFDK6UyaeKgmW1mygvSIudsl/nbbQ=";
            };
            cargoDeps = old.cargoDeps.overrideAttrs {
              inherit src;
              outputHash = "sha256-03vHVC3PSmHMLouQSirPlIG5o7BpvgWjFCtKLAGnxg8=";
              outputHashMode = "recursive";
            };
          }))
          git-open
          git-toolbelt
          difftastic
          cloc
          tom
          tmp-cleanup
        ])
        ++ (with pkgs.unstable; [
          shellcheck
          shfmt
        ]);
    }

    # Interactive userland — folded from the old pkgs/system.nix (a system-level
    # set that only ever landed on home-manager machines). Editor + shell tools
    # for the interactive user; off on minimal home-manager hosts (kradalby-llm).
    # The everyday aliases (cat→bat, vim→nvim, ...) already live in home/fish.nix.
    (lib.mkIf cfg.userland.enable {
      home.packages = let
        fake-editor = import ./scripts/fake-editor.nix {inherit pkgs;};
      in
        [fake-editor]
        ++ (with pkgs; [
          neovim
          fzf
          eternal-terminal
          setec
          nix-tree
          nh
          babelfish
        ]);
    })

    # Go ecosystem
    (lib.mkIf cfg.go.enable {
      programs.go = {
        enable = true;
        package = pkgs.go;
        env.GOPATH = "go";
      };
      home.sessionVariables.GOPATH = "$HOME/go";
      home.packages = with pkgs.unstable; [
        gopls
        delve
        golangci-lint
        go-tools
        gofumpt
        golines
        (lib.lowPrio gotools)
        gotestsum
      ];
    })

    # Nix ecosystem
    (lib.mkIf cfg.nix.enable {
      home.packages = with pkgs.unstable; [
        nixd
        alejandra
        deadnix
        statix
        colmena
        nix-init
        nurl
        ragenix
      ];
    })

    # Web/JS/TS ecosystem
    (lib.mkIf cfg.web.enable {
      home.packages =
        (with pkgs; [
          # nodejs_25
        ])
        ++ (with pkgs.unstable; [
          typescript
          vtsls
          eslint_d
          prettier
          stylelint
          html-tidy
          commitlint
        ]);
    })

    # Python ecosystem
    (lib.mkIf cfg.python.enable {
      home.packages =
        (with pkgs; [
          uv
        ])
        ++ (with pkgs.unstable; [
          ruff
          mypy
          pyright
        ]);
    })

    # Shell ecosystem
    (lib.mkIf cfg.shell.enable {
      home.packages = let
        rmkh = import ./scripts/rmkh.nix {inherit pkgs;};
      in
        [rmkh]
        ++ (with pkgs; [
          nushell
        ])
        ++ (with pkgs.unstable; [
          shellharden
        ]);
    })

    # General editor support
    (lib.mkIf cfg.editor.enable {
      home.packages = with pkgs.unstable; [
        editorconfig-checker
        lua-language-server
        lua54Packages.luadbi-sqlite3
        lua54Packages.luasql-sqlite3
        terraform-ls
        yaml-language-server
        yamllint
        gitlint
        actionlint
        vale
        write-good
      ];
    })

    # Infrastructure and ops
    (lib.mkIf cfg.infra.enable {
      home.packages =
        (with pkgs; [
          ansible
          headscale
          nmap
          ipcalc
          (docker_29.override {clientOnly = true;})
          dive
          act
        ])
        ++ (with pkgs.unstable; [
          tailscale-tools
          ts-preauthkey
          prek
        ]);
    })

    # Media and data
    (lib.mkIf cfg.media.enable {
      home.packages = let
        exif-set-photographer = import ./scripts/exif-set-photographer.nix {inherit pkgs;};
      in
        [exif-set-photographer]
        ++ (with pkgs; [
          ffmpeg
          exiftool
          qrencode
          cook-cli
          sqldiff
          sql-studio
        ])
        ++ (with pkgs.unstable; [
          squibble
        ]);
    })

    # AI coding assistants
    (lib.mkIf cfg.ai.enable {
      home.packages = let
        ac = import ./scripts/ac.nix {inherit pkgs;};
      in
        [ac]
        ++ (with pkgs; [
          nodejs_24
          python3
        ])
        ++ (with pkgs.master; [
          claude-code
          # codex
          gemini-cli
        ])
        ++ lib.optionals cfg.ai.opencode [
          pkgs.opencode
        ];
    })

    # Darwin-specific packages (not togglable)
    (lib.mkIf pkgs.stdenv.isDarwin {
      home.packages = let
        pamtouchfix = import ./scripts/pamtouchfix.nix {inherit pkgs;};
        rsync-photos-backup = import ./scripts/rsync-photos-backup.nix {inherit pkgs;};
        exportphotos = import ./scripts/exportphotos.nix {inherit pkgs;};
        tailscale-switch-toggle = import ./scripts/tailscale-switch-toggle.nix {inherit pkgs;};
        ghostty-new-mosh-tab = import ./scripts/ghostty-new-mosh-tab.nix {inherit pkgs;};
      in
        [pamtouchfix rsync-photos-backup exportphotos tailscale-switch-toggle ghostty-new-mosh-tab]
        ++ (with pkgs; [
          ghostty-tab
          syncthing
          silicon
        ])
        ++ (with pkgs.unstable; [
          lima-full
          colima
        ]);
    })

    # Linux-specific packages (not togglable)
    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        incus
      ];
    })
  ];
}
