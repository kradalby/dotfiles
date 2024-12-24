{
  config,
  pkgs,
  lib,
  ...
}: let
  domain = "nextcloud.kradalby.no";

  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  cfg = import ../../metadata/syncthing.nix;
  syncthingDomain = "syncthing.core.${config.networking.domain}";
in
  lib.mkMerge [
    {
      # age.secrets.nextcloud = {
      #   file = ../../secrets/nextcloud.age;
      #   owner = "nextcloud";
      # };

      services.nextcloud = {
        enable = false;

        # NOTE: manual update required
        # https://search.nixos.org/packages?channel=24.05&from=0&size=50&sort=relevance&type=packages&query=nextcloud
        package = pkgs.nextcloud29;

        hostName = domain;
        # Enable built-in virtual host management
        # Takes care of somewhat complicated setup
        # See here: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/nextcloud.nix#L529
        # nginx.enable = true;

        # Use HTTPS for links
        https = true;

        # Auto-update Nextcloud Apps
        autoUpdateApps.enable = true;
        # Set what time makes sense for you
        autoUpdateApps.startAt = "05:00:00";

        config = {
          # Further forces Nextcloud to use HTTPS
          overwriteProtocol = "https";

          # Nextcloud PostegreSQL database configuration, recommended over using SQLite
          dbtype = "pgsql";
          dbuser = "nextcloud";
          dbhost = "/run/postgresql"; # nextcloud will add /.s.PGSQL.5432 by itself
          dbname = "nextcloud";
          # dbpassFile = "/var/nextcloud-db-pass";

          adminpassFile = config.age.secrets.nextcloud.path;
          adminuser = "admin";
        };
      };

      security.acme.certs."${domain}".domain = domain;

      services.nginx.virtualHosts."${domain}" = {
        forceSSL = true;
        useACMEHost = domain;

        # Redirect openid to the installed application
        # according to docs:
        # https://github.com/H2CK/oidc/wiki/User-Documentation
        locations."/.well-known/openid-configuration" = {
          priority = 1;
          extraConfig = ''
            absolute_redirect off;
            return 301 /index.php/apps/oidc/openid-configuration;
          '';
          # return = "301 /index.php/apps/oidc/openid-configuration";
        };

        extraConfig = ''
          access_log /var/log/nginx/${domain}.access.log;
        '';
      };

      systemd.services."nextcloud-setup" = {
        requires = ["postgresql.service"];
        after = ["postgresql.service"];
      };

      services.syncthing = {
        user = "nextcloud";
        dataDir = "${config.services.nextcloud.datadir}/syncthing";
        enable = true;
        guiAddress = "0.0.0.0:8443";
        overrideDevices = true;
        overrideFolders = true;
        settings = {
          inherit (cfg) devices;
          folders = {
            "kradalby - Sync" = {
              id = "xTDuT-kZeuK";
              # Name of folder in Syncthing, also the folder ID
              path = "${config.services.nextcloud.datadir}/syncthing/Sync";
              devices = builtins.attrNames config.services.syncthing.settings.devices;
              type = "receiveonly"; # sendreceive
            };
          };
        };
      };
    }

    (nginx.internalVhost {
      domain = syncthingDomain;
      proxyPass = "http://127.0.0.1:8384";
    })
  ]
