{
  lib,
  pkgs,
  config,
  ...
}: {
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
  ];

  users = {
    users = {
      litestream = {
        extraGroups = ["uptime-kuma" config.services.golink.group];
      };
    };
  };
}
