{
  pkgs,
  config,
  lib,
  ...
}: {
  imports = [./var.nix];

  config = {
    environment = {
      shellAliases =
        config.my.shellAliases
        // {
          s = ''${pkgs.findutils}/bin/xargs ${pkgs.perl}/bin/perl -pi -E'';
          ag = "rg";
          cat = "bat";
          du = "du -hs";
          mkdir = "mkdir -p";
          nvim = "nvim -p";
          vim = "nvim -p";
          watch = "viddy --differences";
        };

      shells = [pkgs.bashInteractive pkgs.zsh pkgs.fish];
    };
  };
}
