{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [ ./var.nix ];

  config = {
    environment = {
      enableAllTerminfo = lib.mkIf pkgs.stdenv.isLinux true;

      # Only lightweight aliases here; package-referencing ones (which pull
      # neovim/ripgrep/bat/... into a closure) live in home/fish.nix so they
      # land on the interactive user's home-manager shells only, not on servers.
      shellAliases = config.my.shellAliases // {
        du = "du -hs";
        mkdir = "mkdir -p";
      };

      shells = [
        pkgs.bashInteractive
        pkgs.zsh
        pkgs.fish
      ];

      # `secret NAME` resolver: setec over the tailnet (curl, 1s) with an op
      # fallback. Light (curl, no setec binary) so it ships on every host.
      # `secret-env` resolves many at once in parallel (used by the secret_env
      # direnv helper). Both ship everywhere.
      systemPackages = [
        (import ../pkgs/scripts/secret.nix { inherit pkgs; })
        (import ../pkgs/scripts/secret-env.nix { inherit pkgs; })
      ];
    };
  };
}
