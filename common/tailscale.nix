{
  config,
  lib,
  ...
}: let
  cfg = config.services.tailscale;
  hostname = builtins.replaceStrings [".fap.no" "."] ["" "-"] config.networking.fqdn;
in {
  # Extend the upstream Tailscale submodule with convenience options
  # for tags and route advertisement. These translate to extraSetFlags
  # and extraUpFlags automatically.
  options.services.tailscale = lib.mkOption {
    type = lib.types.submodule {
      options = {
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
    };
  };

  config = {
    # Primary Tailscale instance: upstream SaaS (kradalby.no tailnet).
    # TUN mode with full routing features.
    services.tailscale = {
      enable = true;

      authKeyFile = config.age.secrets.tailscale-preauthkey.path;
      useRoutingFeatures = "both";

      extraSetFlags =
        [
          "--ssh=true"
          "--accept-dns=true"
          "--accept-routes=true"
          "--advertise-exit-node"
          "--advertise-connector"
          "--webclient=true"
          "--hostname=${hostname}"
        ]
        ++ lib.optional ((builtins.length cfg.advertiseRoutes) > 0)
        "--advertise-routes=${builtins.concatStringsSep "," cfg.advertiseRoutes}";

      extraUpFlags =
        []
        ++ lib.optional ((builtins.length cfg.tags) > 0)
        "--advertise-tags=${builtins.concatStringsSep "," cfg.tags}";
    };

    # Secondary Tailscale instance: headscale.kradalby.no.
    # Userspace networking (no TUN conflicts with the primary instance).
    age.secrets.headscale-client-preauthkey = {
      file = ../secrets/headscale-client-preauthkey.age;
    };

    services.tailscales.headscale = {
      enable = true;
      authKeyFile = config.age.secrets.headscale-client-preauthkey.path;
      extraUpFlags = ["--login-server=https://headscale.kradalby.no"];
      extraSetFlags = ["--hostname=${hostname}"];
    };
  };
}
