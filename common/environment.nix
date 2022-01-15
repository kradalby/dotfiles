{ config, lib, ... }: {

  imports = [ ./var.nix ];

  config.environment = {
    shellAliases = config.my.shellAliases // { };
  };
}
