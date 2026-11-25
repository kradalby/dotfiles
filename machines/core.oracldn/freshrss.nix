{ config, lib, ... }:
let
  hostname = "rss.dalby.ts.net";
  state = "/var/lib/freshrss";
  runtime = "/run/freshrss-serve";
  socket = "${runtime}/backend/http.sock";
  hostAddress = "192.168.253.1";
  localAddress = "192.168.253.2";
  healthPort = 63468;
in
{
  services.tailscale.services.rss.endpoints."tcp:443" = "tls-terminated-tcp://unix:${socket}";
  networking.nat.internalInterfaces = [ "ve-freshrss" ];
  # The container module configures this peer; networkd's 80-container-ve adds competing addresses.
  systemd.network.networks."10-ve-freshrss" = {
    matchConfig.Name = "ve-freshrss";
    linkConfig.Unmanaged = true;
  };

  # First activation can run the backup before FreshRSS creates its database.
  systemd.services.sqlite-backup-freshrss.unitConfig.ConditionPathExists =
    config.services.sqlite-backup.freshrss.databasePath;

  systemd.tmpfiles.rules = [
    "d ${state} 0700 44880 44880 -"
    # The host's nginx shares the guest's numeric UID. Only root may traverse the host parent.
    "d ${runtime} 0700 root root -"
    "d ${runtime}/backend 0700 ${toString config.ids.uids.nginx} ${toString config.ids.gids.nginx} -"
  ];

  containers.freshrss = {
    inherit hostAddress localAddress;
    autoStart = true;
    privateNetwork = true;
    bindMounts = {
      "${state}" = {
        hostPath = state;
        isReadOnly = false;
      };
      "/run/rss-backend" = {
        hostPath = "${runtime}/backend";
        isReadOnly = false;
      };
    };
    config = { config, pkgs, ... }: {
      imports = [ ../../common/resolved.nix ];
      system.stateVersion = "26.05";
      networking.useHostResolvConf = false;
      networking.firewall.allowedTCPPorts = [ healthPort ];
      users.users.freshrss.uid = 44880;
      users.groups.freshrss.gid = 44880;

      systemd.services = lib.mkMerge [
        (lib.genAttrs [ "freshrss-config" "freshrss-updater" ] (_: {
          serviceConfig.StateDirectoryMode = "0700";
        }))
        {
          # Public WebSub hubs cannot deliver callbacks to a tailnet VIP.
          freshrss-config.postStart = ''
            ${pkgs.php}/bin/php -r '
              require "${config.services.freshrss.package}/cli/_cli.php";
              $conf = FreshRSS_Context::systemConf();
              if ($conf->pubsubhubbub_enabled) {
                $conf->pubsubhubbub_enabled = false;
                exit($conf->save() ? 0 : 1);
              }
            '
          '';
          nginx = {
            # A hard stop can leave the socket inode behind on the host bind mount.
            preStart = lib.mkBefore "rm -f /run/rss-backend/http.sock";
            serviceConfig.ReadWritePaths = [ "/run/rss-backend" ];
          };
        }
      ];

      services.freshrss = {
        enable = true;
        defaultUser = "kradalby";
        authType = "none";
        # Set the per-user API password under Profile before connecting Reeder Classic.
        api.enable = true;
        baseUrl = "https://${hostname}";
        virtualHost = hostname;
      };

      services.nginx.virtualHosts."${hostname}" = {
        listen = [ { addr = "unix:/run/rss-backend/http.sock"; } ];
        extraConfig = "absolute_redirect off;";
        locations."~ ^.+?\\.php(/.*)?$".extraConfig = lib.mkAfter ''
          fastcgi_param HTTPS on;
        '';
      };

      # The host probe can check Google Reader without access to the passwordless UI.
      services.nginx.virtualHosts."rss-health" = {
        listen = [
          {
            addr = localAddress;
            port = healthPort;
          }
        ];
        locations."/".return = "404";
        locations."= /api/greader.php/check/compatibility".extraConfig = ''
          allow ${hostAddress};
          deny all;
          proxy_pass http://unix:/run/rss-backend/http.sock:/api/greader.php/check/compatibility;
        '';
      };
    };
  };
}
