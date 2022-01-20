{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Development
    buf
    dockfmt
    dyff
    entr
    gh
    git-open
    go-jsonnet
    gofumpt
    golangci-lint
    gox
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
    yarn

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


    # clang_13

    # golines
    # swiftlint
    # clang-format
    # hclfmt

  ];
}
