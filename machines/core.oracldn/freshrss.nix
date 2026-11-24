{ lib, ... }:
let
  hostname = "rss.dalby.ts.net";
  port = 63468;
  state = "/var/lib/freshrss";
in
{
  services.tailscale.services.rss.endpoints."tcp:443" =
    "tls-terminated-tcp://127.0.0.1:${toString port}";

  systemd.tmpfiles.rules = [ "d ${state} 0700 44880 44880 -" ];

  containers.freshrss = {
    autoStart = true;
    privateNetwork = false;
    bindMounts."${state}" = {
      hostPath = state;
      isReadOnly = false;
    };
    config = {
      system.stateVersion = "26.05";
      networking.firewall.enable = false;
      users.users.freshrss.uid = 44880;
      users.groups.freshrss.gid = 44880;

      systemd.services = lib.genAttrs [ "freshrss-config" "freshrss-updater" ] (_: {
        serviceConfig.StateDirectoryMode = "0700";
      });

      services.freshrss = {
        enable = true;
        defaultUser = "kradalby";
        authType = "none";
        api.enable = true;
        baseUrl = "https://${hostname}";
        virtualHost = hostname;
      };

      services.nginx.virtualHosts."${hostname}" = {
        listen = [
          {
            addr = "127.0.0.1";
            inherit port;
          }
        ];
        extraConfig = "absolute_redirect off;";
        # Serve terminates TLS before forwarding the original HTTP request.
        locations."~ ^.+?\\.php(/.*)?$".extraConfig = lib.mkAfter ''
          fastcgi_param HTTPS on;
        '';
      };
    };
  };
}
