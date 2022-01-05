{ pkgs, config, lib, ... }:
{
  services.unifi = {
    unifiPackage = pkgs.unifi;
    enable = true;
    openFirewall = true;

    # initialJavaHeapSize = 1024;
    # maximumJavaHeapSize = 1536;


  };

  networking.firewall.allowedTCPPorts = [ 8443 ];

  security.acme.certs."unifi.ldn.fap.no".domain = "unifi.ldn.fap.no";

  services.nginx.virtualHosts."unifi.ldn.fap.no" = {
    forceSSL = true;
    useACMEHost = "unifi.ldn.fap.no";
    locations."/" = {
      proxyPass = "https://127.0.0.1:8443";
      proxyWebsockets = true;
      extraConfig =
          "proxy_set_header Host $host;" +
          "proxy_set_header X-Real-IP $remote_addr;" +
          "proxy_set_header X-Forward-For $proxy_add_x_forwarded_for;" +
          "proxy_read_timeout 86400;"
          ;
    };
  };
}
