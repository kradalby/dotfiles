{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../../common/postgres.nix ];

  my.postgres.databases = [ "umami" ];

  my.postgres.extraBackups = [ ];

  # Listen only where clients exist: loopback + the docker bridge gateway.
  # enableTCPIP's default was *, exposing postgres to the whole private subnet
  # via the trusted LAN interface.
  services.postgresql.settings.listen_addresses = lib.mkForce "127.0.0.1,172.17.0.1";

  # Allow the dockerized umami container to connect via trust auth. /24, not
  # /16: the default bridge allocates container addresses from 172.17.0.0/24.
  services.postgresql.authentication = ''
    host  umami  umami  172.17.0.0/24   trust
  '';

  # 172.17.0.1 exists only once dockerd creates docker0; a parallel boot
  # start binds loopback-only (postgres logs the failed bind at LOG level and
  # carries on) and umami can't connect until a manual restart.
  systemd.services.postgresql = {
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
  };

  # Major upgrade per the nixpkgs manual (postgresql.md, "Upgrading"): run this,
  # then switch services.postgresql.package. Switching first starts postgres on
  # an empty data dir and umami migrates a fresh schema.
  environment.systemPackages = [
    (
      let
        newPostgres = pkgs.postgresql_17;
        cfg = config.services.postgresql;
      in
      pkgs.writeScriptBin "upgrade-pg-cluster" ''
        set -eux
        systemctl stop docker-umami.service postgresqlBackup-umami.timer postgresql.service

        export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"
        export NEWBIN="${newPostgres}/bin"
        export OLDDATA="${cfg.dataDir}"
        export OLDBIN="${cfg.finalPackage}/bin"

        install -d -m 0700 -o postgres -g postgres "$NEWDATA"
        cd "$NEWDATA"
        # Idempotent, so a --check run can precede the real one. Encoding and
        # locale must match the old cluster or pg_upgrade refuses; pinned rather
        # than inherited from whichever shell runs this.
        [ -e "$NEWDATA/PG_VERSION" ] || \
          sudo -u postgres "$NEWBIN/initdb" -D "$NEWDATA" \
            --encoding=UTF8 --locale=en_US.UTF-8 ${lib.escapeShellArgs cfg.initdbArgs}

        sudo -u postgres "$NEWBIN/pg_upgrade" \
          --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
          --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
          "$@"
      ''
    )
  ];
}
