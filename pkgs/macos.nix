{ pkgs, ... }: {
  home.packages = with pkgs;
    (if stdenv.isDarwin then
      [
        terminal-notifier
      ] else [ ]
    );
}
