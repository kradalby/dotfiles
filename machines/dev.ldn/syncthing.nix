{ config, lib, ... }:
let
  cfg = import ../../metadata/syncthing.nix;
in
{
  services.syncthings = {
    personal = {
      enable = true;
      user = "kradalby";
      group = "users";
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
            # storage.bassan only gets this folder encrypted, from
            # core.tjoda/storage.ldn (common/syncthing-storage.nix); keep it
            # out of this plain device list.
            devices = lib.filter (d: d != "storage.bassan") (
              builtins.attrNames config.services.syncthings.personal.settings.devices
            );
            type = "sendreceive";
          };
        };
      };
    };
  };

  services.tailscale.services.syncthing-dev-ldn = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:8384";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://127.0.0.1:8384";
    };
  };
}
