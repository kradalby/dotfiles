{
  config,
  lib,
  ...
}: let
  cfg = import ../metadata/syncthing.nix;
  location =
    let
      components = lib.splitString "." config.networking.domain;
    in
      lib.elemAt components 0;
  tailscaleService = "svc:syncthing-${location}";
in {
  services = {
    syncthing = {
      user = "storage";
      group = "storage";
      dataDir = "/storage";
      enable = true;
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        inherit (cfg) devices;
        gui.insecureSkipHostcheck = true;
        folders = {
          "/storage/software" = {
            id = "vpgyn-cj2mg";
            path = "/storage/software";
            devices = cfg.storage;
            type = "sendreceive";
          };

          "/storage/pictures" = {
            id = "orqnv-bg72d";
            path = "/storage/pictures";
            devices = cfg.storage;
            type = "sendreceive";
          };

          "/storage/backup" = {
            id = "9bjac-k65uu";
            path = "/storage/backup";
            devices = cfg.storage;
            type = "sendreceive";
          };

          "/storage/books" = {
            id = "ww4gn-xgy9i";
            path = "/storage/books";
            devices = cfg.storage;
            type = "sendreceive";
          };

          "kradalby - Sync" = {
            id = "xTDuT-kZeuK";
            path = "/storage/sync/kradalby";
            devices = builtins.attrNames config.services.syncthing.settings.devices;
            type = "sendreceive";
          };
        };
      };
    };

    tailscale.services.${tailscaleService} = {
      endpoints = {
        "tcp:80" = "http://127.0.0.1:8384";
        "tcp:443" = "http://127.0.0.1:8384";
      };
    };
  };
}
