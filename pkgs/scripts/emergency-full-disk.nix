{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "emergency-full-disk";
  text = ''
    EMPTY_FILE_PATH=/delete_me.empty
    if [ -f $EMPTY_FILE_PATH ]; then
      rm $EMPTY_FILE_PATH
    fi

    journalctl --vacuum-size=500M

    if command -v docker &> /dev/null
    then
      docker system prune -af || echo "Docker not available, skipping prune..."
    fi

    nix-env -p /nix/var/nix/profiles/system --delete-generations +2
    nix-collect-garbage --delete-older-than 1d

    fallocate -l 2G $EMPTY_FILE_PATH
  '';
}
