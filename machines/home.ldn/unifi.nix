{ pkgs, config, lib, ... }:
let
  consul = import ../../common/funcs/consul.nix { inherit lib; };

  domain = "unifi.${config.networking.domain}";
in
{
  services.unifi = {
    unifiPackage = pkgs.unifi;
    enable = true;
    openFirewall = true;

    # initialJavaHeapSize = 1024;
    # maximumJavaHeapSize = 1536;
  };
  systemd.services.unifi.onFailure = [ "notify-discord@%n.service" ];

  # TODO: Remove 8443 when nginx can correctly proxy
  networking.firewall.allowedTCPPorts = [ 8443 9130 ];

  security.acme.certs."${domain}".domain = domain;

  # TODO: Figure out why this loops indefinetly
  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations = {
      "/" = {
        proxyPass = "https://localhost:8443/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Accept-Encoding "";
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Front-End-Https on;
          proxy_redirect off;
        '';
      };
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };

  sops.secrets.unifi-read-only = {
    mode = "0400";
    owner = "unifi-poller";
  };

  services.unifi-poller = {
    enable = true;

    unifi.defaults = {
      url = "https://127.0.0.1:8443";
      user = "read-only";
      pass = config.sops.secrets.unifi-read-only.path;

      verify_ssl = false;
    };

    influxdb.disable = true;

    prometheus = {
      http_listen = ":9130";
    };
  };

  systemd.services.prometheus-unifi-exporter.onFailure = [ "notify-discord@%n.service" ];
  my.consulServices.unifi_exporter = consul.prometheusExporter "unifi" config.services.prometheus.exporters.unifi.port;

}
