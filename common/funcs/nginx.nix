{
  config,
  lib,
}: let
  internalVhost = {
    domain,
    proxyPass,
    proxyWebsockets ? true,
    tailscaleAuth ? true,
    allowLocal ? false,
    locationExtraConfig ? "",
  }: {
    security.acme.certs."${domain}".domain = domain;

    services.nginx.virtualHosts."${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      locations."/" = {
        inherit proxyPass;
        inherit proxyWebsockets;
        extraConfig =
          ""
          + lib.optionalString allowLocal ''
            allow 10.0.0.0/8;
            satisfy any;
          ''
          + lib.optionalString tailscaleAuth config.services.tailscale-nginx-auth.authConfig
          + locationExtraConfig;
      };
      extraConfig =
        ''
          access_log /var/log/nginx/${domain}.access.log;
        ''
        + lib.optionalString tailscaleAuth config.services.tailscale-nginx-auth.internalRoute;
    };
  };
in {inherit internalVhost;}
