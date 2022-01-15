{ config, ... }:
let
  domain = "consul.${config.networking.domain}";
in
{

  imports = [ ./consul.nix ];

  services.consul = {
    enable = true;
    webUi = true;

    extraConfig = {
      server = true;
      bootstrap = true;

      bind_addr = ''{{ GetInterfaceIP "${config.my.lan}" }}'';

      retry_join = [ ];
      retry_join_wan = [ ];

      connect = {
        enabled = true;
      };
    };
  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8500";
      proxyWebsockets = true;
    };
  };

}
