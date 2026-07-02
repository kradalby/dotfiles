{
  pkgs,
  lib,
  ...
}: {
  # Minimal system toolset every machine gets — servers, the minimal ts1p
  # appliance, and workstations (root included). Cross-platform: imported by
  # common/base.nix (NixOS) and common/darwin/kradalby-base.nix (Darwin).
  # The fuller interactive userland lives in home-manager (pkgs/home-packages.nix).
  environment.systemPackages = with pkgs;
    [
      ripgrep
      fd
      jq
      git
      htop
      procs
      tree
      rsync
      wget
      unzip
      zstd
      mosh
      tmux
      lsof

      # jemalloc, which bind depends on, is broken on darwin aarch64
      (lib.mkIf (! (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)) dig)
    ]
    ++ lib.optionals stdenv.isLinux [
      ncdu
      nftables
    ];
}
