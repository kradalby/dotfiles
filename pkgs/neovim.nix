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
    golangci-lint-langserver
    nil
    nodePackages.typescript
    nodePackages.typescript-language-server
    # nodePackages.vscode-langservers-extracted
    nodePackages.yaml-language-server
    nodePackages_latest.pyright
    rust-analyzer
    sumneko-lua-language-server
    terraform-ls
    nixd
    nodePackages."@tailwindcss/language-server"
    master.gopls

    ## null-ls
    # curlylint
    # djlint
    actionlint
    alejandra
    beautysh
    black
    buf
    # cbfmt
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
    shellcheck
    shellharden
    shfmt
    statix
    vale
    yamllint

    python312Packages.flake8
    python312Packages.pylama

    ## Debug

    # Use unstable to ensure we get a modern version,
    # we need to have one that is at least as new as Go.
    unstable.delve

    ## Unconfigured
    dockfmt
    gh
    hadolint

    # Zed
    # elmPackages.elm
    elmPackages.elm-test
    elmPackages.elm-language-server
  ];
}
