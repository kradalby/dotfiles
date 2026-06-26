{
  config,
  inputs,
  pkgs,
  ...
}: {
  age.secrets.tsnixcache-sign-key.file =
    ../../secrets/tsnixcache-sign-key.age; # from: tsnixcache key generate
  age.secrets.tsnixcache-tsnet-authkey.file =
    ../../secrets/tsnixcache-tsnet-authkey.age; # authkey, kradalby tailnet
  # headscale-sfiber-client-preauthkey is declared in default.nix (host sfiber
  # instance); the sfiber tsnet below reuses it.

  services.tsnixcache = {
    enable = true;
    package = inputs.tsnixcache.packages.${pkgs.system}.default;
    signKeyFile = config.age.secrets.tsnixcache-sign-key.path;

    listen = ["10.68.0.1:5000"]; # local/subnet only, never wan0
    serveCompression = "zstd";

    # Serve on two control planes: the kradalby tailnet and the sandefjordfiber
    # headscale. Same hostname, distinct nodes (separate dir state).
    tsnet = [
      {
        hostname = "tsnixcache";
        authKeyFile = config.age.secrets.tsnixcache-tsnet-authkey.path;
        dir = "/var/lib/tsnixcache/tsnet-kradalby";
      }
      {
        hostname = "tsnixcache";
        controlUrl = "https://headscale.sandefjordfiber.no";
        authKeyFile = config.age.secrets.headscale-sfiber-client-preauthkey.path;
        dir = "/var/lib/tsnixcache/tsnet-sfiber";
      }
    ];

    # Disk-pressure GC so /nix/store on NVMe0 never fills. Last rule is the
    # emergency valve: near-full, drop anything older than a day.
    gc.rules = [
      {
        threshold = 80;
        olderThan = "20d";
      }
      {
        threshold = 90;
        olderThan = "10d";
      }
      {
        threshold = 95;
        olderThan = "5d";
      }
      {
        threshold = 99;
        olderThan = "1d";
      }
    ];
  };
}
