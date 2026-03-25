{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.packages;
  tom = import ./scripts/tom.nix {inherit pkgs;};
in {
  options.my.packages = {
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
        ])
        ++ (with pkgs.unstable; [
          shellcheck
          shfmt
        ]);
    }

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
        gotools
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
          # nodejs_24
        ])
        ++ (with pkgs.unstable; [
          nodePackages.typescript
          vtsls
          nodePackages.eslint_d
          nodePackages.prettier
          nodePackages.stylelint
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
      home.packages =
        (with pkgs; [
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
        lua53Packages.luadbi-sqlite3
        lua53Packages.luasql-sqlite3
        terraform-ls
        nodePackages.yaml-language-server
        yamllint
        gitlint
        actionlint
        vale
        nodePackages.write-good
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
          docker-client
          dive
          act
        ])
        ++ (with pkgs.unstable; [
          tmuxinator
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
          rtk
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
      in
        [pamtouchfix rsync-photos-backup]
        ++ (with pkgs; [
          boo
          terminal-notifier
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
