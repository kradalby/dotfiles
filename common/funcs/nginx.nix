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
    allowCors ? false,
  }: {
    security.acme.certs."${domain}".domain = domain;

    services.nginx.virtualHosts."${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      locations."/" = {
        inherit proxyPass;
        inherit proxyWebsockets;
        extraConfig = lib.optionalString allowCors ''
          add_header 'Access-Control-Allow-Origin' '*' always;
          add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
          add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
          add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
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
