{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs;
    [
      fish

      neovim

      # jemalloc, which bind depends on is broken on darwin aarch64
      (lib.mkIf (! (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)) dig)
      vim
      babelfish
      bat
      coreutils
      dos2unix
      eza
      fd
      fdupes
      fish
      fzf
      git
      htop
      jq
      lsof
      mosh
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
      yq-go
      rsync
      viddy
      zstd

      # Nix tooling
      nix-diff
      nix-tree
      unstable.attic

      (let
        my-python-packages = python-packages:
          with python-packages; [
            requests
          ];
        python-with-my-packages = python3.withPackages my-python-packages;
      in
        python-with-my-packages)
    ]
    ++ lib.optionals stdenv.isLinux [
      nftables
      usbutils
      ncdu
    ];
}
