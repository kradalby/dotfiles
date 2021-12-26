{ pkgs, ... }: {
  home.packages =
    (if pkgs.stdenv.isDarwin then
      [
        pkgs.terminal-notifier
      ] else [ ]
    );
}
