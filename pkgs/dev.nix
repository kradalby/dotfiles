{ pkgs, ... }: {
  home.packages = [
    # Development
    pkgs.buf
    pkgs.dockfmt
    pkgs.dyff
    pkgs.entr
    pkgs.gh
    pkgs.git-open
    pkgs.go
    pkgs.go-jsonnet
    pkgs.gofumpt
    pkgs.golangci-lint
    pkgs.gox
    pkgs.hadolint
    pkgs.html-tidy
    pkgs.nodePackages.eslint_d
    pkgs.nodePackages.lua-fmt
    pkgs.nodePackages.prettier
    pkgs.nodejs
    pkgs.poetry
    pkgs.pre-commit
    # pkgs.rnix-lsp
    pkgs.shfmt
    pkgs.yarn

    (pkgs.fenix.complete.withComponents
      [
        "cargo"
        "clippy"
        "rust-src"
        "rustc"
        "rustfmt"
      ])

    # pkgs.clang_13

    # pkgs.golines
    # pkgs.swiftlint
    # pkgs.clang-format
    # pkgs.hclfmt

  ];
}