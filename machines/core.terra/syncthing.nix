{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: let
  cfg = import ../../metadata/syncthing.nix;
  domain = "syncthing.core.${config.networking.domain}";
in {
  services = {
    syncthing = {
      inherit (cfg) devices;
      user = "storage";
      group = "storage";
      dataDir = "/storage";
      enable = true;
      overrideDevices = true;
      overrideFolders = true;
      folders = {
        "/storage/software" = {
          id = "vpgyn-cj2mg";
          path = "/storage/software";
          devices = cfg.storage;
          type = "receiveonly";
        };

        "/storage/pictures" = {
          id = "orqnv-bg72d";
          path = "/storage/pictures";
          devices = cfg.storage;
          type = "receiveonly";
        };

        "/storage/backup" = {
          id = "9bjac-k65uu";
          path = "/storage/backup";
          devices = cfg.storage;
          type = "receiveonly";
        };

        "/fast/album" = {
          id = "qha65-mn9fc";
          path = "/fast/hugin/album";
          devices = ["kraairm2"];
          type = "receiveonly";
        };

        "kradalby - Sync" = {
          id = "xTDuT-kZeuK";
          path = "/storage/sync/kradalby";
          devices = builtins.attrNames config.services.syncthing.devices;
          type = "receiveonly";
        };
      };
    };
  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8384";
      proxyWebsockets = true;
      extraConfig = config.services.tailscale-nginx-auth.authConfig;
    };
    extraConfig =
      ''
        access_log /var/log/nginx/${domain}.access.log;
      ''
      + config.services.tailscale-nginx-auth.internalRoute;
  };
}
