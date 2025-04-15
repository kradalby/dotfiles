{pkgs, ...}: {
  home.packages = with pkgs; [
    # Go
    master.gopls
    master.delve
    golangci-lint-langserver
    golangci-lint
    go-tools # staticcheck
    gofumpt
    golines
    gotools # goimports

    # Nix
    nixd
    alejandra
    deadnix
    statix

    # General
    editorconfig-checker

    ## Tools
    lua53Packages.luadbi-sqlite3 # yank sql
    lua53Packages.luasql-sqlite3 # yank sql

    # Other
    # rust-analyzer
    sumneko-lua-language-server
    terraform-ls
    efm-langserver
    nil
    buf

    # YAML
    nodePackages.yaml-language-server
    yamllint

    # Node/Web/JS
    nodePackages."@tailwindcss/language-server"
    nodePackages.eslint_d
    nodePackages.prettier
    nodePackages.prettier_d_slim
    nodePackages.stylelint
    html-tidy
    nodePackages.typescript
    nodePackages.typescript-language-server

    # Shell
    beautysh
    shellcheck
    shellharden
    shfmt

    # Git / Github
    commitlint
    gitlint
    actionlint

    # Words
    vale
    proselint
    nodePackages.write-good

    # Python
    # python312Packages.flake8
    # python312Packages.pylama
    black
    isort
    mypy
    pyright

    ## Docker
    # dockfmt
    # hadolint

    # Elm
    elmPackages.elm-test
    elmPackages.elm-language-server
  ];
}
