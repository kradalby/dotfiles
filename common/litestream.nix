{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  port = 54909;
  location = lib.elemAt (lib.splitString "." config.networking.domain) 0;
  # Off-site replica to tjoda's garage over its tailnet VIP; restic covers
  # files. Per-host bucket + key (granted only that bucket, via the garage/
  # tofu root in ~/git/infrastructure) so one host's credential can't touch
  # another host's replicas.
  replicate = db: {
    inherit (db) path;
    replica = {
      type = "s3";
      bucket = "litestream-${location}";
      path = db.name;
      endpoint = "http://s3-tjoda.dalby.ts.net:9000";
      region = "garage";
      validation-interval = "24h";
    };
  };
in {
  options = {
    my.litestream.databases = lib.mkOption {
      type = types.listOf (types.attrsOf types.str);
      default = [];
    };
  };

  config = lib.mkIf (config.my.litestream.databases != []) {
    age.secrets.litestream = {
      file = ../secrets + "/litestream-${location}.age";
    };

    services.litestream = {
      enable = true;
      environmentFile = config.age.secrets.litestream.path;
      settings = {
        addr = ":${toString port}";
        dbs = builtins.map replicate config.my.litestream.databases;
      };
    };

    # Replication that can't restore is not a backup. Restore every database
    # from the replica weekly and integrity-check it. A failure lands the unit
    # in "failed" (ServiceFailed pages), and on full success we stamp a
    # timestamp into the node_exporter textfile dir so Prometheus can see the
    # last good restore and alert on staleness (LitestreamRestoreStale).
    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter-textfile 0755 root root -"
    ];
    systemd.services.litestream-restore-test = {
      description = "litestream restore verification";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.age.secrets.litestream.path;
        PrivateTmp = true;
      };
      script =
        ''
          set -euo pipefail
          ok=1
        ''
        + lib.concatMapStrings (db: ''
          out=$(mktemp -d)
          if ! { ${pkgs.litestream}/bin/litestream restore -config /etc/litestream.yml -o "$out/restored.db" "${db.path}" \
                 && ${pkgs.sqlite}/bin/sqlite3 "$out/restored.db" 'PRAGMA integrity_check;' | grep -qx ok; }; then
            ok=0
          fi
          rm -rf "$out"
        '')
        config.my.litestream.databases
        + ''
          d=/var/lib/prometheus-node-exporter-textfile
          if [ "$ok" = 1 ]; then
            printf 'litestream_restore_test_last_success_seconds %s\n' "$(date +%s)" >"$d/.lrt.$$"
            mv "$d/.lrt.$$" "$d/litestream-restore-test.prom"  # atomic for the collector
          fi
          [ "$ok" = 1 ]
        '';
    };

    systemd.timers.litestream-restore-test = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
