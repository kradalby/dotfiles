{ config, lib, ... }:

with lib;

let
  cfg = config.services.vhost;

  vhostType = types.attrsOf (types.submodule (_: {
    options = {
      proxyPass = mkOption {
        type = types.str;
        description = mdDoc "Target passed to nginx `proxy_pass`.";
        example = "http://127.0.0.1:9000";
      };

      proxyWebsockets = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc "Whether to enable websocket proxying for the vhost.";
      };

      basicAuthFile = mkOption {
        type = types.nullOr (types.either types.path types.str);
        default = null;
        description = mdDoc "Optional path to a htpasswd file for HTTP basic auth.";
      };

      allowCors = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc "Append permissive CORS headers to the default location.";
      };
    };
  }));

  corsHeaders = ''
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
  '';
in {
  options.services.vhost = mkOption {
    type = vhostType;
    default = {};
    description = mdDoc ''
      Opinionated nginx vhost helper where the attribute name is the domain.

      Each entry provisions an ACME certificate and creates the corresponding
      `services.nginx.virtualHosts.<domain>` definition with sane defaults.
    '';
    example = literalExpression ''
      {
        "example.com" = {
          proxyPass = "http://127.0.0.1:4000";
          basicAuthFile = config.age.secrets.my-basic-auth.path;
        };
      }
    '';
  };

  config = mkIf (cfg != {}) {
    security.acme.certs =
      mapAttrs (domain: _: { inherit domain; }) cfg;

    services.nginx.virtualHosts =
      mapAttrs (domain: vhostCfg: {
        forceSSL = true;
        useACMEHost = domain;
        locations."/" = {
          proxyPass = vhostCfg.proxyPass;
          proxyWebsockets = vhostCfg.proxyWebsockets;
          extraConfig = optionalString vhostCfg.allowCors corsHeaders;
        };
        basicAuthFile = vhostCfg.basicAuthFile;
        extraConfig = ''
          access_log /var/log/nginx/${domain}.access.log;
        '';
      })
      cfg;
  };
}
