{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.fish

    pkgs.unstable.neovim
    pkgs.vim
    pkgs.babelfish
    pkgs.bat
    pkgs.coreutils
    pkgs.dos2unix
    pkgs.exa
    pkgs.fd
    pkgs.fdupes
    pkgs.fish
    pkgs.fzf
    pkgs.git
    pkgs.htop
    pkgs.jq
    pkgs.lsof
    pkgs.mosh
    pkgs.ncdu
    pkgs.p7zip
    pkgs.procs
    pkgs.python3
    pkgs.rclone
    pkgs.restic
    pkgs.ripgrep
    pkgs.socat
    pkgs.tldr
    pkgs.tmux
    pkgs.tree
    pkgs.unzip
    pkgs.viddy
    pkgs.wget
    pkgs.yq
    pkgs.usbutils

    # Neovim plugins
    pkgs.sqlite
    pkgs.gcc

    # Nix tooling
    pkgs.unstable.nodePackages.node2nix
    pkgs.nixpkgs-fmt
  ];
}
