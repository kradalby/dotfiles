{ pkgs, ... }:
{
  home.packages = with pkgs; [
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
    act

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

    # (lib.mkIf pkgs.stdenv.isLinux swift)
    (lib.mkIf pkgs.stdenv.isLinux docker)

    # null-ls only support 0.4.0, so override
    # to ensure we use stable for now.
    stable.statix

    nixpkgs-fmt
    manix

    # clang_13

    # swiftlint
    # clang-format
    # hclfmt

  ];
}
