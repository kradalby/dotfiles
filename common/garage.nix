{
  pkgs,
  lib,
  config,
  ...
}:
let
  location = lib.elemAt (lib.splitString "." config.networking.domain) 0;
  serviceName = "s3-${location}";
in
{
  # GARAGE_RPC_SECRET + GARAGE_ADMIN_TOKEN. The admin token also lives in
  # setec (infra/garage/tjoda/admin-token) for the garage/ tofu root in
  # ~/git/infrastructure, which manages buckets/keys over the admin API.
  age.secrets.garage = {
    file = ../secrets/garage.age;
  };

  services.garage = {
    enable = true;
    # No default on purpose upstream: major bumps need the Garage release
    # notes (offline migrations), so pin the major explicitly.
    package = pkgs.garage_2;
    environmentFile = config.age.secrets.garage.path;
    settings = {
      replication_factor = 1;
      # sqlite over the default lmdb: lmdb is documented corruption-prone on
      # unclean shutdown, and with replication_factor=1 there is no replica
      # to heal from.
      db_engine = "sqlite";

      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";

      s3_api = {
        api_bind_addr = "127.0.0.1:3900";
        s3_region = "garage";
        root_domain = ".s3.garage";
      };

      # Static-site endpoint; inert until a bucket enables website access.
      # Routes by Host header, so a bucket aliased to a VIP hostname is
      # served by pointing that VIP's tcp:80 here.
      s3_web = {
        bind_addr = "127.0.0.1:3902";
        root_domain = ".web.garage";
      };

      # /health is unauthenticated and /metrics is public (no metrics_token,
      # same stance as MinIO's MINIO_PROMETHEUS_AUTH_TYPE=public); everything
      # else needs GARAGE_ADMIN_TOKEN. Localhost only — reached via the VIP.
      admin.api_bind_addr = "127.0.0.1:3903";
    };
  };

  # The nixpkgs module hardcodes a plain `garage server`; --single-node
  # auto-creates the one-node layout on first boot (no-op afterwards).
  systemd.services.garage.serviceConfig = {
    ExecStart = lib.mkForce "${lib.getExe config.services.garage.package} server --single-node";
    # Static user instead of the module's DynamicUser: the data dirs live
    # outside /var/lib (see per-machine config) and need stable ownership.
    DynamicUser = false;
    User = "garage";
    Group = "garage";
  };

  users.users.garage = {
    isSystemUser = true;
    group = "garage";
  };
  users.groups.garage = { };

  services.tailscale.services.${serviceName} = {
    endpoints = {
      # S3 API for cross-site consumers (litestream replicas, backups);
      # reachable via the svc:s3-* grants in the tailnet policy.
      "tcp:9000" = "http://127.0.0.1:3900";
      # Admin API: prometheus metrics/health, and tofu applies from
      # ~/git/infrastructure/garage.
      "tcp:3903" = "http://127.0.0.1:3903";
    };
  };
}
