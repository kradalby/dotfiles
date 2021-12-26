{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.fish

    # pkgs.unstable.neovim
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
    pkgs.mosh
    pkgs.ncdu
    pkgs.p7zip
    pkgs.unzip
    pkgs.procs
    pkgs.python3
    pkgs.rclone
    pkgs.restic
    pkgs.ripgrep
    pkgs.socat
    pkgs.tldr
    pkgs.tmux
    pkgs.tree
    pkgs.viddy
    pkgs.wget
    pkgs.yq
    pkgs.babelfish

    # Neovim plugins
    pkgs.sqlite
    pkgs.gcc
  ];
}
