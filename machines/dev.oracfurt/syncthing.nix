{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: let
  cfg = import ../../metadata/syncthing.nix;
  domain = "syncthing.dev.${config.networking.domain}";
in {
  services = {
    syncthing = {
      inherit (cfg) devices;
      user = "kradalby";
      dataDir = "/home/kradalby";
      enable = true;
      overrideDevices = true;
      overrideFolders = true;
      folders = {
        "kradalby - Sync" = {
          id = "xTDuT-kZeuK";
          # Name of folder in Syncthing, also the folder ID
          path = "/home/kradalby/Sync"; # Which folder to add to Syncthing
          devices = builtins.attrNames config.services.syncthing.devices; # Which devices to share the folder with
          type = "sendreceive";
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
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
