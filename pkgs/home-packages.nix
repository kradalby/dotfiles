{
  pkgs,
  lib,
  ...
}: let
  # Import scripts
  pamtouchfix = import ./scripts/pamtouchfix.nix {inherit pkgs;};
  exif-set-photographer = import ./scripts/exif-set-photographer.nix {inherit pkgs;};
  tom = import ./scripts/tom.nix {inherit pkgs;};
  
  # Go 1.25 overrides for go tools
  goTools = with pkgs.unstable; {
    gopls = gopls.override {buildGoLatestModule = pkgs.buildGo125Module;};
    delve = delve.override {buildGoModule = pkgs.buildGo125Module;};
    golangci-lint = golangci-lint.override {buildGo125Module = pkgs.buildGo125Module;};
    golangci-lint-langserver = golangci-lint-langserver.override {buildGoModule = pkgs.buildGo125Module;};
    go-tools = go-tools.override {buildGoModule = pkgs.buildGo125Module;};
    gofumpt = gofumpt.override {buildGoModule = pkgs.buildGo125Module;};
    golines = golines.override {buildGoModule = pkgs.buildGo125Module;};
    gotools = gotools.override {buildGoModule = pkgs.buildGo125Module;};
    gotestsum = gotestsum.override {buildGoModule = pkgs.buildGo125Module;};
  };

  # Stable packages
  stablePackages = with pkgs; [
    # CLI / Shell Enhancements
    bat # cat clone with syntax highlighting
    eza # ls replacement
    viddy # modern watch command
    prettyping # ping with a graph
    entr # run arbitrary commands when files change
    eb # exp backoff

    # Dev / Git
    gh # github cli
    git-absorb # git commit --fixup on steroids
    git-open # open repo in browser
    git-toolbelt # set of useful git scripts
    difftastic # structural diff tool
    cloc # count lines of code
    act # run GitHub Actions locally

    # Containers / K8s
    docker # container engine
    dive # docker image explorer

    # Network / Infrastructure
    ansible # automation tool
    headscale # open source tailscale control server
    ipcalc # ip address calculator
    nmap # network scanner
    ts-preauthkey # tailscale preauth key generator

    # Media / Files
    ffmpeg # video/audio converter
    exiftool # read/write meta information in files
    qrencode # qr code generator

    # Language / Runtime
    nodejs_24 # javascript runtime
    uv # python package installer

    # Database
    sqldiff # diff for sqlite databases
    sql-studio # sqlite database manager

    # Scripts
    exif-set-photographer # script to set photographer in exif
    tom # script to clean up git repos
  ];

  # Unstable tools
  unstableTools = with pkgs.unstable; [
    # setec
    squibble # sqlite lib tool
    tailscale-tools # tailscale tools
    prek # pre-commit tool

    # Nix
    colmena # nixos deployment tool
    nix-init # generate nix packages from urls
    nurl # nix url fetcher
    ragenix # age encryption for nix
  ];

  # AI tools
  aiTools = with pkgs.unstable; [
    codex # OpenAI CLI
    gemini-cli # Gemini CLI
    claude-code # Anthropic CLI
    claude-code-acp # Bridge for Claude and Zed
    claude-monitor # Monitor for Claude
  ];

  # Go tools (with Go 1.25)
  goPackages = with goTools; [
    gopls # go language server
    delve # go debugger
    golangci-lint-langserver # golangci-lint language server
    golangci-lint # go linter
    go-tools # staticcheck
    gofumpt # stricter gofmt
    golines # go formatter
    gotools # goimports
    gotestsum # go test runner with output
  ];

  # Editor tooling
  editorTooling = with pkgs.unstable; [
    # Nix
    nixd # nix language server
    alejandra # nix formatter
    deadnix # dead code finder for nix
    statix # linter for nix
    nil # nix language server
    nixpkgs-fmt # nix formatter

    # General
    editorconfig-checker # verify editorconfig compliance

    # Tools
    lua53Packages.luadbi-sqlite3 # yank sql
    lua53Packages.luasql-sqlite3 # yank sql

    # Other
    # rust-analyzer
    lua-language-server # lua language server
    terraform-ls # terraform language server
    efm-langserver # general purpose language server
    buf # protobuf tool

    # YAML
    nodePackages.yaml-language-server # yaml language server
    yamllint # yaml linter

    # Node/Web/JS
    nodePackages."@tailwindcss/language-server" # tailwindcss language server
    nodePackages.eslint_d # eslint daemon
    nodePackages.prettier # code formatter
    nodePackages.prettier_d_slim # faster prettier
    nodePackages.stylelint # css linter
    html-tidy # html linter/formatter
    nodePackages.typescript # typescript compiler
    nodePackages.typescript-language-server # typescript language server

    # Shell
    beautysh # shell formatter
    shellcheck # shell script analysis tool
    shellharden # shell script hardener
    shfmt # shell formatter

    # Git / Github
    commitlint # lint commit messages
    gitlint # lint git commit messages
    actionlint # lint github actions

    # Words
    vale # prose linter
    proselint # prose linter
    nodePackages.write-good # english prose linter

    # Python
    # python312Packages.flake8
    # python312Packages.pylama
    black # python formatter
    isort # python import sorter
    mypy # python static type checker
    pyright # python static type checker

    # Docker
    # dockfmt
    # hadolint

    # Elm
    elmPackages.elm-test # elm test runner
    elmPackages.elm-language-server # elm language server
  ];

  # Darwin-specific packages
  darwinPackages = [pamtouchfix]
    ++ (with pkgs; [
      terminal-notifier # send macos user notifications
      syncthing # continuous file synchronization
      silicon # create beautiful images of your source code
      virt-manager # desktop user interface for managing virtual machines
      qemu # generic and open source machine emulator and virtualizer
    ])
    ++ (with pkgs.unstable; [
      lima # linux virtual machines
      colima # container runtimes on macos
    ]);

  # Linux-specific packages
  linuxPackages = with pkgs; [
    # swift
    incus # system container and virtual machine manager
  ];
in {
  home.packages =
    stablePackages
    ++ unstableTools
    ++ aiTools
    ++ goPackages
    ++ editorTooling
    ++ lib.optionals pkgs.stdenv.isDarwin darwinPackages
    ++ lib.optionals pkgs.stdenv.isLinux linuxPackages;
}
