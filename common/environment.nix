{
  pkgs,
  config,
  lib,
  ...
}: {
  imports = [./var.nix];

  config = {
    environment = {
      enableAllTerminfo = lib.mkIf pkgs.stdenv.isLinux true;

      # Only lightweight aliases here; package-referencing ones (which pull
      # neovim/ripgrep/bat/... into every closure) live in pkgs/system.nix so
      # they land on workstations only, not servers.
      shellAliases =
        config.my.shellAliases
        // {
          du = "du -hs";
          mkdir = "mkdir -p";
        };

      shells = [pkgs.bashInteractive pkgs.zsh pkgs.fish];
    };
  };
}
