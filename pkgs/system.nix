{ pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    fish

    unstable.neovim
    dig
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
    python3
    rclone
    restic
    ripgrep
    socat
    tldr
    tmux
    tree
    unzip
    viddy
    wget
    yq
    rsync

    # Linux only
    (lib.mkIf pkgs.stdenv.isLinux usbutils)

    # Neovim plugins
    gcc

    # Nix tooling
    unstable.nodePackages.node2nix
    nixpkgs-fmt
  ];
}
