{
  config,
  lib,
  ...
}:
let
  cfg = config.services.tailscale;
  hostname = builtins.replaceStrings [ ".fap.no" "." ] [ "" "-" ] config.networking.fqdn;
in
{
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
          default = [ ];
        };
        advertiseRoutes = lib.mkOption {
          description = ''
            List of routes to advertise to other nodes.
          '';
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };
    };
  };

  # Every userspace instance gets an outbound SOCKS5+HTTP proxy by default.
  # ponytail: all plural instances share :1056 — fine because no host runs
  # more than one today. A second userspace instance on one host trips the
  # module's proxyListenAddress uniqueness assertion at build; give that one
  # an explicit port then.
  options.services.tailscales = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config = {
          proxy = lib.mkDefault "both";
          proxyListenAddress = lib.mkDefault "localhost:1056";
        };
      }
    );
  };

  config = {
    # Hardening: every Tailscale instance (primary + each services.tailscales.*)
    # opens an outbound SOCKS5/HTTP proxy. If two land on the same 127.0.0.1
    # port, the second daemon fails "address already in use", crash-loops, and
    # the node silently drops off the tailnet — no build error, discovered only
    # when something can't reach it. The upstream plural assertion misses this:
    # it compares only plural proxyListenAddress values, ignoring the primary and
    # any raw --socks5-server/--outbound-http-proxy-listen in extraDaemonFlags
    # (which override proxyListenAddress at the daemon). Assert the *effective*
    # ports every instance binds are unique across the whole host, at eval.
    assertions =
      let
        portOf = a: lib.toInt (lib.last (lib.splitString ":" a));
        rawPort =
          flags: prefix:
          let
            f = lib.findFirst (x: lib.hasPrefix prefix x) null flags;
          in
          if f == null then null else portOf (lib.removePrefix prefix f);
        # Ports an instance actually binds for its outbound proxies.
        proxyPorts =
          inst:
          let
            flags = inst.extraDaemonFlags or [ ];
            base = if (inst.proxy or "none") != "none" then portOf inst.proxyListenAddress else null;
            pick =
              prefix:
              let
                r = rawPort flags prefix;
              in
              if r != null then r else base;
          in
          lib.unique (
            lib.filter (p: p != null) [
              (pick "--socks5-server=")
              (pick "--outbound-http-proxy-listen=")
            ]
          );
        instances =
          lib.optional config.services.tailscale.enable config.services.tailscale
          ++ lib.attrValues config.services.tailscales;
        ports = lib.concatMap proxyPorts instances;
      in
      [
        {
          assertion = ports == lib.unique ports;
          message =
            "tailscale: outbound-proxy port collision on ${config.networking.hostName} "
            + "(effective ports ${lib.concatMapStringsSep ", " toString ports}). Each Tailscale "
            + "instance needs a unique proxyListenAddress port; don't hand-roll a colliding "
            + "--socks5-server in extraDaemonFlags.";
        }
      ];

    # Primary Tailscale instance: upstream SaaS (kradalby.no tailnet).
    # TUN mode with full routing features.
    services.tailscale = {
      enable = true;

      authKeyFile = config.age.secrets.tailscale-preauthkey.path;
      useRoutingFeatures = "both";

      # Outbound SOCKS5+HTTP proxy on the module default localhost:1055.
      proxy = "both";

      extraSetFlags = [
        "--ssh=true"
        "--accept-dns=true"
        "--accept-routes=true"
        "--advertise-exit-node"
        "--advertise-connector"
        "--webclient=true"
        "--hostname=${hostname}"
      ]
      ++ lib.optional (
        (builtins.length cfg.advertiseRoutes) > 0
      ) "--advertise-routes=${builtins.concatStringsSep "," cfg.advertiseRoutes}";

      extraUpFlags =
        [ ]
        ++ lib.optional (
          (builtins.length cfg.tags) > 0
        ) "--advertise-tags=${builtins.concatStringsSep "," cfg.tags}";
    };

    # Secondary Tailscale instance: headscale.kradalby.no.
    # Userspace networking (no TUN conflicts with the primary instance).
    #
    # DISABLED: headscale.kradalby.no is currently offline, so this instance would
    # just churn retrying. Re-enable (and rekey headscale-client-preauthkey to add
    # any new hosts) once it is back up.
    # age.secrets.headscale-client-preauthkey = {
    #   file = ../secrets/headscale-client-preauthkey.age;
    # };
    #
    # services.tailscales.headscale = {
    #   enable = true;
    #   authKeyFile = config.age.secrets.headscale-client-preauthkey.path;
    #   extraUpFlags = ["--login-server=https://headscale.kradalby.no"];
    #   extraSetFlags = ["--hostname=${hostname}"];
    # };
  };
}
