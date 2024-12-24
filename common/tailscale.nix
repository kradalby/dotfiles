{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.services.tailscale;
in {
  options.services.tailscale = {
    tags = lib.mkOption {
      description = ''
        List of tags to advertise to other nodes.
      '';
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    advertiseRoutes = lib.mkOption {
      description = ''
        List of routes to advertise to other nodes.
      '';
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config.services.tailscale = {
    enable = true;

    authKeyFile = config.age.secrets.tailscale-preauthkey.path;
    useRoutingFeatures = "both";

    extraSetFlags =
      [
        "--ssh=true"
        "--accept-dns=false"
        "--advertise-exit-node"
        "--advertise-connector"
        "--webclient=true"
        ''--hostname=${builtins.replaceStrings [".fap.no"] [""] config.networking.fqdn}''
      ]
      ++ lib.optional ((builtins.length cfg.advertiseRoutes) > 0) ''--advertise-routes=${builtins.concatStringsSep "," cfg.advertiseRoutes}'';

    extraUpFlags =
      [
      ]
      ++ lib.optional ((builtins.length cfg.tags) > 0) ''--advertise-tags=${builtins.concatStringsSep "," cfg.tags}'';
  };
}
