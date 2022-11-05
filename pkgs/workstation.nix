{
  pkgs,
  lib,
  # , flakes
  ...
}: {
  home.packages = with pkgs;
    [
      # act
      # buf
      # go-jsonnet
      # imapchive
      # logcli
      # nodejs
      # osxphotos
      # poetry
      # rnix-lsp
      # yarn
      ansible
      colmena
      dockfmt
      drone-cli
      dyff
      eb
      editorconfig-checker
      entr
      exiftool
      gh
      git-open
      gitlint
      grpcurl
      hadolint
      headscale
      html-tidy
      ipcalc
      kubectl
      kubernetes-helm
      libiconv # rnix-lsp
      lua53Packages.luadbi-sqlite3 # yank sql
      lua53Packages.luasql-sqlite3 # yank sql
      nmap
      nodePackages.eslint_d
      nodePackages.node2nix
      nodePackages.prettier
      nodejs # ansiblels
      pre-commit
      prettyping
      python310Packages.pylama
      qrencode
      ragenix
      shellcheck
      shellharden
      shfmt
      step-cli
      unstable.dotnet-sdk # omnisharp
      vale
      silicon

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
      # swift
    ];
}
