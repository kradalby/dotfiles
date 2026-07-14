{
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    ../../common/litestream.nix
  ];

  my.litestream.databases = [
    {
      name = "kuma.db";
      path = "/var/lib/uptime-kuma/kuma.db";
    }
    {
      name = "golink.db";
      path = config.services.golink.databaseFile;
    }
    {
      name = "headscale.sqlite";
      path = "/var/lib/headscale/db.sqlite";
    }
  ];

  users = {
    users = {
      litestream = {
        extraGroups = [
          "uptime-kuma"
          config.services.golink.group
          "headscale"
        ];
      };
    };
  };

  # litestream (in the headscale group) writes its shadow dir inside the
  # headscale state dir; the module default 0750 denies group write, so
  # headscale replication silently failed. kuma/golink dirs are 0770.
  systemd.services.headscale.serviceConfig.StateDirectoryMode = lib.mkForce "0770";
}
