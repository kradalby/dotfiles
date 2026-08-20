{
  config,
  pkgs,
  lib,
  ...
}:
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
        # Pin the default transfer port to this instance; without explicit
        # listenAddresses the cooklang instance raced it for :22000 and this
        # one ended up on a random port, which dev.ldn rejected.
        options.listenAddresses = [ "tcp://:22000" ];
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
            # out of this plain device list. The cooklang instance only
            # accepts krair/kratail2 — sharing to it just redials forever.
            devices = lib.filter (d: d != "storage.bassan" && d != "dev.oracfurt-cooklang") (
              builtins.attrNames config.services.syncthings.personal.settings.devices
            );
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
          "kratail2" = cfg.devices."kratail2";
        };
        # Own transfer port so it stops racing the personal instance for
        # :22000 (peers find the port via discovery).
        options.listenAddresses = [ "tcp://:22001" ];
        gui = {
          insecureSkipHostcheck = true;
          insecureAdminAccess = true;
        };
        folders = {
          "cooklang-recipes" = {
            id = "cooklang-recipes";
            path = "/var/lib/cook-server";
            devices = [
              "krair"
              "kratail2"
            ];
            type = "sendreceive";
          };
        };
      };
    };
  };

  # Peers are all tailnet devices; open the transfer ports on tailscale0
  # explicitly (services.md tier-3) instead of riding the implicit accept.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    22000
    22001
  ];

  services.tailscale.services.syncthing-dev-oracfurt = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:8384";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://127.0.0.1:8384";
    };
  };

  # The cooklang recipe-sync syncthing instance (backs the cook-server app)
  # gets its own VIP so its scrape target and ACL grant are self-documenting.
  services.tailscale.services.syncthing-cooklang = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:8385";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      # Must be served: services.tf registers this VIP with tcp:443, and a VIP
      # that leaves a declared port unserved is never distributed to the
      # tailnet (`tailscale whois` on its address: peer not found).
      "tcp:443" = "http://127.0.0.1:8385";
    };
  };
}
