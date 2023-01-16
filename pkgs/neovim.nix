{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Tools
    fd
    ripgrep
    lua53Packages.luadbi-sqlite3 # yank sql
    lua53Packages.luasql-sqlite3 # yank sql
    libiconv # rnix-lsp

    # LSP
    efm-langserver
    gopls
    nil
    nodePackages.yaml-language-server
    rnix-lsp
    sumneko-lua-language-server
    terraform-ls
    buf-language-server
    dhall-lsp-server
    golangci-lint-langserver
    rust-analyzer

    # EFM
    buf
    python310Packages.flake8
    mypy
    nodePackages.stylelint
    nodePackages.prettier
    shfmt
    yamllint

    # null-ls
    actionlint
    alejandra
    beautysh
    black
    cbfmt
    clang
    commitlint
    # curlylint
    deadnix
    # djlint
    editorconfig-checker
    gitlint
    html-tidy
    isort
    jq
    nodePackages.prettier_d_slim
    nodePackages.eslint_d
    proselint
    python310Packages.pylama
    shellcheck
    shellharden
    go-tools # staticcheck
    statix
    vale
    nodePackages.write-good

    # Debug
    delve

    # Unconfigured
    dockfmt
    gh
    hadolint
  ];
}