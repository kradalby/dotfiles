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
      eternal-terminal
      p7zip
      procs
      rclone
      restic
      ripgrep
      rsync
      socat
      tldr
      boo
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
      nftables
      usbutils
      ncdu
      (import ./scripts/emergency-full-disk.nix {inherit pkgs;})
    ];

  # Interactive aliases that pull their tools into the closure; workstation-only
  # (this module is imported by kratail2/krair/dev.ldn, not by servers).
  environment.shellAliases = {
    s = ''${pkgs.findutils}/bin/xargs ${pkgs.perl}/bin/perl -pi -E'';
    ag = "${pkgs.ripgrep}/bin/rg";
    cat = "${pkgs.bat}/bin/bat";
    nvim = "${pkgs.neovim}/bin/nvim -p";
    vim = "${pkgs.neovim}/bin/nvim -p";
    watch = "${pkgs.viddy}/bin/viddy --differences";
  };
}
