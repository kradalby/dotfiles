{
  pkgs,
  lib,
  # , flakes
  ...
}: {
  home.packages = with pkgs;
    [
      # Workstation
      drone-cli
      exiftool
      ipcalc
      kubectl
      kubernetes-helm
      nmap
      prettyping
      qrencode
      headscale
      step-cli
      colmena
      ragenix
      ansible

      # nix tooling
      nodePackages.node2nix

      # imapchive

      # logcli

      python39Packages.pipx
      # osxphotos
      # Development
      # buf
      dockfmt
      dyff
      entr
      gh
      git-open
      gitlint
      # go-jsonnet
      hadolint
      html-tidy
      nodePackages.eslint_d

      # nodePackages.lua-fmt

      nodePackages.prettier
      # nodejs
      # poetry
      pre-commit
      # rnix-lsp
      shfmt
      shellharden
      shellcheck
      # yarn
      editorconfig-checker
      grpcurl
      # act
      vale

      # neovim plugin deps
      libiconv # rnix-lsp
      nodejs # ansiblels
      unstable.dotnet-sdk # omnisharp
      lua53Packages.luasql-sqlite3 # yank sql
      lua53Packages.luadbi-sqlite3 # yank sql

      (fenix.complete.withComponents
        [
          "cargo"
          "clippy"
          "rust-src"
          "rustc"
          "rustfmt"
        ])

      # gofumpt
      # golangci-lint
      # gox
      # golines

      # null-ls only support 0.4.0, so override
      # to ensure we use stable for now.
      stable.statix

      alejandra
      deadnix

      nixpkgs-fmt
      manix

      # Tailscale stuff
      redo-apenwarr

      clang

      # swiftlint
      # clang-format
      # hclfmt
      docker
    ]
    ++ lib.optionals stdenv.isDarwin [
      unstable.lima
      unstable.colima
      terminal-notifier
    ]
    ++ lib.optionals stdenv.isLinux [
      swift
    ];
}
