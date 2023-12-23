{
  config,
  lib,
}: let
  internalVhost = {
    domain,
    proxyPass,
    proxyWebsockets ? true,
    tailscaleAuth ? true,
    allowLocal ? true,
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

  externalVhost = {
    domain,
    proxyPass,
    proxyWebsockets ? true,
    basicAuthFile ? null,
  }: {
    security.acme.certs."${domain}".domain = domain;

    services.nginx.virtualHosts."${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      locations."/" = {
        inherit proxyPass;
        inherit proxyWebsockets;
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };
      inherit basicAuthFile;
      extraConfig = ''
        access_log /var/log/nginx/${domain}.access.log;
      '';
    };
  };
in {
  inherit internalVhost;
  inherit externalVhost;
}
