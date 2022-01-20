{ pkgs, config, lib, ... }: {

  imports = [ ./var.nix ];

  config.environment = {
    shellAliases = config.my.shellAliases // { };

    shells = [ pkgs.bashInteractive pkgs.zsh pkgs.fish ];
  };
}
