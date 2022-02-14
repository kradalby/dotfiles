{ config, lib, pkgs, ... }:
let
  consul = import ./funcs/consul.nix { inherit lib; };
in
{

  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.listen = lib.mkDefault [
        { addr = "0.0.0.0"; port = 60443; ssl = true; }
        { addr = "[::]"; port = 60443; ssl = true; }
      ];
    });
  };

  config = {
    services.nginx = {

      enable = true;
      package = pkgs.nginx;

      defaultListenAddresses = [ "127.0.0.1" "[::1]" ];

      statusPage = true;

      # Use recommended settings
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = false;
      recommendedTlsSettings = true;

      # Only allow PFS-enabled ciphers with AES256
      sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";

      commonHttpConfig = ''
        # Add HSTS header with preloading to HTTPS requests.
        # Adding this header to HTTP requests is discouraged
        # map $scheme $hsts_header {
        #     https   "max-age=31536000; includeSubdomains; preload";
        # }
        # add_header Strict-Transport-Security $hsts_header;

        # Enable CSP for your services.
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

        # Minimize information leaked to other domains
        add_header 'Referrer-Policy' 'origin-when-cross-origin';

        # Disable embedding as a frame
        add_header X-Frame-Options DENY;

        # Prevent injection of code in other mime types (XSS Attacks)
        add_header X-Content-Type-Options nosniff;

        # Enable XSS protection of the browser.
        # May be unnecessary when CSP is configured properly (see above)
        add_header X-XSS-Protection "1; mode=block";

        # This might create errors
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      '';
    };

    systemd.services.nginx.onFailure = [ "notify-discord@%n.service" ];

    networking.firewall.allowedTCPPorts = [ 80 443 ];
    networking.firewall.allowedUDPPorts = [ 443 ];

    services.prometheus.exporters.nginx = {
      enable = true;
      openFirewall = true;
    };

    systemd.services."prometheus-nginx-exporter".onFailure = [ "notify-discord@%n.service" ];

    my.consulServices.nginx_exporter = consul.prometheusExporter "nginx" config.services.prometheus.exporters.nginx.port;

    services.prometheus.exporters.nginxlog = {
      enable = true;
      openFirewall = true;

      group = "nginx";
      user = "nginx";

      settings = {
        namespaces =
          let
            # format = ''
            #   $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"
            # '';

            mkApp = domain: {
              name = domain;
              metrics_override = { prefix = "nginxlog"; };
              source.files = [ "/var/log/nginx/${domain}.access.log" ];
              namespace_label = "vhost";
            };
          in
          [
            {
              name = "catch";
              metrics_override = { prefix = "nginxlog"; };
              source.files = [ "/var/log/nginx/access.log" ];
              namespace_label = "vhost";
            }
          ] ++ builtins.map mkApp (builtins.attrNames config.services.nginx.virtualHosts);
      };
    };

    systemd.services."prometheus-nginxlog-exporter".onFailure = [ "notify-discord@%n.service" ];

    my.consulServices.nginxlog_exporter = consul.prometheusExporter "nginxlog" config.services.prometheus.exporters.nginxlog.port;
  };

}
