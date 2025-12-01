{
  config,
  lib,
  pkgs,
  ...
}: let
in {
  options.my.enableSslh = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.listen = lib.mkIf config.my.enableSslh (
        lib.mkDefault [
          {
            addr = "0.0.0.0";
            port = 80;
            ssl = false;
          }
          {
            addr = "0.0.0.0";
            port = 60443;
            ssl = true;
          }
          {
            addr = "[::]";
            port = 80;
            ssl = false;
          }
          {
            addr = "[::]";
            port = 60443;
            ssl = true;
          }
        ]
      );
    });
  };

  imports = [
    ./sslh.nix
    ../modules/tailscale-nginx-auth.nix
  ];

  config = {
    services = {
      tailscale-nginx-auth.enable = true;

      nginx = {
        enable = true;
        package = pkgs.nginx;

        # defaultListenAddresses = [ "127.0.0.1" "[::1]" ];

        statusPage = true;

        # Use recommended settings
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        recommendedGzipSettings = true;
        recommendedBrotliSettings = true;

        # Only allow PFS-enabled ciphers with AES256
        sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
      };

      prometheus.exporters.nginxlog = {
        enable = true;

        group = "nginx";
        user = "nginx";

        settings = {
          namespaces = let
            # format = ''
            #   $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"
            # '';
            mkApp = domain: {
              name = domain;
              metrics_override = {prefix = "nginxlog";};
              source.files = ["/var/log/nginx/${domain}.access.log"];
              namespace_label = "vhost";
            };
          in
            [
              {
                name = "catch";
                metrics_override = {prefix = "nginxlog";};
                source.files = ["/var/log/nginx/access.log"];
                namespace_label = "vhost";
              }
            ]
            ++ builtins.map mkApp (builtins.attrNames config.services.nginx.virtualHosts);
        };
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf config.networking.firewall.enable
      [80 config.services.prometheus.exporters.nginxlog.port];

  };
}
