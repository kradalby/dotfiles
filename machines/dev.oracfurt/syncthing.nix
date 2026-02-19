{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = import ../../metadata/syncthing.nix;
in {
  services.syncthing = {
    user = "kradalby";
    dataDir = "/home/kradalby";
    enable = true;
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
          devices = builtins.attrNames config.services.syncthing.settings.devices;
          type = "sendreceive";
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
