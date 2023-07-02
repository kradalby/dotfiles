{pkgs, ...}: {
  home.packages = with pkgs; [
    # Tools
    fd
    ripgrep
    lua53Packages.luadbi-sqlite3 # yank sql
    lua53Packages.luasql-sqlite3 # yank sql
    libiconv # rnix-lsp

    # LSP
    efm-langserver
    unstable.gopls
    nil
    nodePackages.yaml-language-server
    nodePackages.vscode-langservers-extracted
    # rnix-lsp
    nixd
    sumneko-lua-language-server
    terraform-ls
    buf-language-server
    dhall-lsp-server
    golangci-lint-langserver
    rust-analyzer
    elmPackages.elm-language-server
    nodePackages.typescript-language-server
    nodePackages.typescript

    # EFM
    buf
    python310Packages.flake8
    mypy
    nodePackages.stylelint
    nodePackages.prettier
    shfmt
    yamllint
    golines
    gofumpt

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
    gotools # goimports
    statix
    vale
    nodePackages.write-good

    # Debug

    # Use unstable to ensure we get a modern version,
    # we need to have one that is at least as new as Go.
    unstable.delve

    # Unconfigured
    dockfmt
    gh
    hadolint
  ];
}
