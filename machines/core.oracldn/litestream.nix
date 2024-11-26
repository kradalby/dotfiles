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
    {
      name = "headscale.sqlite";
      path = "/var/lib/headscale/db.sqlite";
    }
    {
      name = "kanidm.db";
      path = "/var/lib/kanidm/kanidm.db";
    }
  ];

  users = {
    users = {
      litestream = {
        extraGroups = ["uptime-kuma" config.services.golink.group "headscale" "kanidm"];
      };
    };
  };
}
