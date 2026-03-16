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
      wget
      yq-go
      zstd
      nix-diff
      nix-tree
      wush

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
