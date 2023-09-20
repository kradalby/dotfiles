{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Tools
    fd
    ripgrep
    lua53Packages.luadbi-sqlite3 # yank sql
    lua53Packages.luasql-sqlite3 # yank sql
    libiconv # rnix-lsp

    ## LSP
    ansible-language-server
    buf-language-server
    dhall-lsp-server
    efm-langserver
    elmPackages.elm-language-server
    golangci-lint-langserver
    nil
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    nodePackages.yaml-language-server
    nodePackages_latest.pyright
    rust-analyzer
    sumneko-lua-language-server
    terraform-ls
    unstable.gopls
    unstable.nixd

    ## null-ls
    # curlylint
    # djlint
    actionlint
    alejandra
    beautysh
    black
    buf
    cbfmt
    clang
    commitlint
    deadnix
    editorconfig-checker
    gitlint
    go-tools # staticcheck
    gofumpt
    golines
    gotools # goimports
    html-tidy
    isort
    jq
    mypy
    nodePackages.eslint_d
    nodePackages.prettier_d_slim
    nodePackages.stylelint
    nodePackages.write-good
    proselint
    python310Packages.flake8
    python310Packages.pylama
    shellcheck
    shellharden
    shfmt
    statix
    vale
    yamllint

    ## Debug

    # Use unstable to ensure we get a modern version,
    # we need to have one that is at least as new as Go.
    unstable.delve

    ## Unconfigured
    dockfmt
    gh
    hadolint
  ];
}
