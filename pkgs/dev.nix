{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Development
    buf
    dockfmt
    dyff
    entr
    gh
    git-open
    gitlint
    go-jsonnet
    hadolint
    html-tidy
    nodePackages.eslint_d
    nodePackages.lua-fmt
    nodePackages.prettier
    nodejs
    poetry
    pre-commit
    # rnix-lsp
    shfmt
    shellharden
    shellcheck
    yarn
    editorconfig-checker

    lua53Packages.luasql-sqlite3
    lua53Packages.luadbi-sqlite3

    (fenix.complete.withComponents
      [
        "cargo"
        "clippy"
        "rust-src"
        "rustc"
        "rustfmt"
      ])

    gofumpt
    golangci-lint
    gox
    golines

    (lib.mkIf pkgs.stdenv.isLinux swift)

    statix
    nixpkgs-fmt

    # clang_13

    # swiftlint
    # clang-format
    # hclfmt

  ];
}
