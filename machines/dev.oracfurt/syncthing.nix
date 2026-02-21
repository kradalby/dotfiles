{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = import ../../metadata/syncthing.nix;
in {
  services.syncthings = {
    personal = {
      enable = true;
      user = "kradalby";
      dataDir = "/home/kradalby";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        inherit (cfg) devices;
        gui = {
          insecureSkipHostcheck = true;
          insecureAdminAccess = true;
        };
        folders = {
          "kradalby - Sync" = {
            id = "xTDuT-kZeuK";
            path = "/home/kradalby/Sync";
            devices = builtins.attrNames config.services.syncthings.personal.settings.devices;
            type = "sendreceive";
          };
        };
      };
    };

    cooklang = {
      enable = true;
      user = "cook-server";
      group = "cook-server";
      guiAddress = "127.0.0.1:8385";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        devices = {
          "krair" = cfg.devices."krair";
        };
        gui = {
          insecureSkipHostcheck = true;
          insecureAdminAccess = true;
        };
        folders = {
          "cooklang-recipes" = {
            id = "cooklang-recipes";
            path = "/var/lib/cook-server";
            devices = ["krair"];
            type = "sendreceive";
          };
        };
      };
    };
  };

  services.tailscale.services."svc:syncthing-dev-oracfurt" = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:8384";
      "tcp:443" = "http://127.0.0.1:8384";
    };
  };
}
