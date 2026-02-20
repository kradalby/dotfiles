{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs;
    [
      nh
      fish

      neovim

      # jemalloc, which bind depends on is broken on darwin aarch64
      (lib.mkIf (! (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)) dig)
      babelfish
      coreutils
      dos2unix
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
      rsync
      socat
      tldr
      tmux
      tree
      unzip
      vim
      wget
      yq-go
      zstd
      nix-diff
      nix-tree
      attic-client
      wush

      (let
        my-python-packages = python-packages:
          with python-packages; [
            requests
          ];
        python-with-my-packages = python3.withPackages my-python-packages;
      in
        python-with-my-packages)

      (import ./scripts/fake-editor.nix {inherit pkgs;})
    ]
    ++ lib.optionals stdenv.isLinux [
      ghostty.terminfo
      nftables
      usbutils
      ncdu
      (import ./scripts/emergency-full-disk.nix {inherit pkgs;})
    ];
}
