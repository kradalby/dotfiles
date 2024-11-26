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
      attic-client

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
      (writeShellApplication {
        name = "emergency-full-disk";
        text = ''
          EMPTY_FILE_PATH=/delete_me.empty
          if [ -f $EMPTY_FILE_PATH ]; then
            rm $EMPTY_FILE_PATH
          fi

          journalctl --vacuum-size=500M

          if command -v docker &> /dev/null
          then
            docker system prune -af
          fi

          nix-env -p /nix/var/nix/profiles/system --delete-generations +2
          nix-collect-garbage --delete-older-than 1d

          fallocate -l 2G $EMPTY_FILE_PATH
        '';
      })
    ];
}
