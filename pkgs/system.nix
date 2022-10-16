{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    fish

    neovim

    # jemalloc, which bind depends on is broken on darwin aarch64
    (lib.mkIf (! (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)) dig)
    vim
    babelfish
    bat
    coreutils
    dos2unix
    exa
    fd
    fdupes
    fish
    fzf
    git
    htop
    jq
    lsof
    mosh
    ncdu
    p7zip
    procs
    rclone
    restic
    ripgrep
    socat
    tldr
    tmux
    tree
    unzip
    wget
    yq
    rsync
    viddy
    zstd

    # Linux only
    (lib.mkIf pkgs.stdenv.isLinux usbutils)

    # Neovim plugins
    gcc

    # Nix tooling
    nixpkgs-fmt
    nix-diff
    nix-tree

    (let
      my-python-packages = python-packages:
        with python-packages; [
          requests
        ];
      python-with-my-packages = python3.withPackages my-python-packages;
    in
      python-with-my-packages)
  ];
}
