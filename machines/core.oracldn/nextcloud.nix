{
  config,
  pkgs,
  lib,
  ...
}: let
  domain = "nextcloud.kradalby.no";
in {
  age.secrets.nextcloud = {
    file = ../../secrets/nextcloud.age;
    owner = "nextcloud";
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud24;

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
    devices = {
      "kramacbook" = {id = "FN7I426-TXAW62Y-NB623TQ-GW23CIO-MWVQM7Q-TSFNI42-XEIZ4NM-HLX2PAE";};
      "core.tjoda" = {id = "T77O75Z-XR4MUNF-R6C2AD6-747KQ3X-M4J24YA-YFH3NVC-WDPYMEN-KCH5NAI";};
      "core.terra" = {id = "CQMXUOP-HPVXOGC-I3GZFS2-XPEK26B-5UCULGA-SGKHNHR-J6FVC2X-UZZQJQV";};
    };
    folders = {
      "kradalby - Sync" = {
        id = "xTDuT-kZeuK";
        # Name of folder in Syncthing, also the folder ID
        path = "${config.services.nextcloud.datadir}/syncthing/Sync"; # Which folder to add to Syncthing
        devices = builtins.attrNames config.services.syncthing.devices; # Which devices to share the folder with
        type = "receiveonly"; # sendreceive
      };
    };
  };
}
