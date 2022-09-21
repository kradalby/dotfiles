{lib, pkgs, config, ...}:{
  imports = [
    ../../common/litestream.nix
  ];

  my.litestream.databases = [
    {name = "headscale.sqlite"; path = "/var/lib/headscale/db.sqlite";}
  ];

    users = {
      users = {
        litestream = {
          extraGroups = ["headscale"];
        };
      };
    };
}
