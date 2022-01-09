{ pkgs, config, lib, ... }:
{
  services.unifi = {
    unifiPackage = pkgs.unifi;
    enable = true;
    openFirewall = true;

    # initialJavaHeapSize = 1024;
    # maximumJavaHeapSize = 1536;
  };
  systemd.services.unifi.onFailure = [ "notify-email@%n.service" ];

  # TODO: Remove 8443 when nginx can correctly proxy
  networking.firewall.allowedTCPPorts = [ 8443 ];

  security.acme.certs."unifi.ldn.fap.no".domain = "unifi.ldn.fap.no";

  # TODO: Figure out why this loops indefinetly
  services.nginx.virtualHosts."unifi.ldn.fap.no" = {
    forceSSL = true;
    useACMEHost = "unifi.ldn.fap.no";
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
  };
  # nginx.config = ''
  #   server {
  #     listen *:443 ssl http2;
  #     listen [::]:443 ssl http2;
  #     server_name unifi.ldn.fap.no;
  #     location / {

  #       proxy_set_header Accept-Encoding "";
  #       proxy_set_header Host $http_host;
  #       proxy_set_header X-Real-IP $remote_addr;
  #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  #       proxy_set_header X-Forwarded-Proto $scheme;
  #       proxy_pass https://localhost:8443/;
  #       proxy_set_header Front-End-Https on;
  #       proxy_redirect off;
  #     }
  #     ${import sub/ssl-settings.nix { inherit domain; }}
  #   }

  #   server {
  #     listen *:80;
  #     listen [::]:80;
  #     server_name unifi.ldn.fap.no;
  #     rewrite ^(.*) https://unifi.ldn.fap.no$1 permanent;
  #   }
  # '';
}
