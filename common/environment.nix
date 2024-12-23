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
          ag = "${pkgs.ripgrep}/bin/rg";
          cat = "${pkgs.bat}/bin/bat";
          du = "du -hs";
          mkdir = "mkdir -p";
          nvim = "${pkgs.neovim}/bin/nvim -p";
          vim = "${pkgs.neovim}/bin/nvim -p";
          watch = "${pkgs.viddy}/bin/viddy --differences";
        };

      shells = [pkgs.bashInteractive pkgs.zsh pkgs.fish];
    };
  };
}
