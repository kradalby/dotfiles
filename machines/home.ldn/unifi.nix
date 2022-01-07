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
    locations."/" = {
      proxyPass = "https://127.0.0.1:8443";
      proxyWebsockets = true;
      extraConfig =
        # "proxy_set_header Host $host;" +
        # "proxy_set_header X-Real-IP $remote_addr;" +
        #  "proxy_set_header X-Forward-For $proxy_add_x_forwarded_for;" +
        #  "proxy_read_timeout 86400;" +
        "proxy_set_header Referer '';" +
        "proxy_set_header Origin '';" +
        "proxy_ssl_verify off;" +
        "proxy_ssl_session_reuse on;" +
        "proxy_buffering off;" +
        "proxy_hide_header Authorization;"
      ;
    };
    # locations."/wss" = {
    #   proxyPass = "https://127.0.0.1:8443";
    #   proxyWebsockets = true;
    #   #  extraConfig =
    #   #"proxy_set_header Upgrade $http_upgrade;" +
    #   #''proxy_set_header Connection "upgrade";'' +
    #   #"proxy_set_header Origin '';" +
    #   #"proxy_buffering off;" +
    #   #"proxy_hide_header Authorization;" +
    #   #"proxy_set_header Referer '';" 
    #   #  ;
    # };
  };
}
