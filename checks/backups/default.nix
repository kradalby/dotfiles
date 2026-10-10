{ pkgs, self }:
let
  lib = pkgs.lib;
  core = self.nixosConfigurations."core.oracldn";
  guardConfig = core.extendModules {
    modules = [
      {
        services.restic.jobs.tjoda.paths = lib.mkForce [
          "required-state"
          "other-state"
        ];
      }
    ];
  };
  guard =
    lib.findFirst (script: lib.hasInfix "restic-source-guard" (toString script))
      (throw "Restic source preflight is missing")
      guardConfig.config.systemd.services.restic-backups-tjoda.serviceConfig.ExecStartPre;
  coreConfig = core.config;
  kuma = coreConfig.systemd.services.uptime-kuma.serviceConfig;
  litestream = coreConfig.systemd.services.litestream;
  kumaTemplate = pkgs.runCommand "kuma-template-test" { nativeBuildInputs = [ pkgs.sqlite ]; } ''
    mkdir -p "$out/lib/node_modules/uptime-kuma/db"
    sqlite3 "$out/lib/node_modules/uptime-kuma/db/kuma.db" \
      'CREATE TABLE items (value INTEGER); INSERT INTO items VALUES (1);'
  '';
  kumaConfig =
    (core.extendModules {
      modules = [
        { services.uptime-kuma.package = lib.mkForce kumaTemplate; }
      ];
    }).config;
  kumaBootstrap = pkgs.writeShellScript "kuma-bootstrap-test" (
    builtins.replaceStrings [ "/var/lib/uptime-kuma" ] [ "fresh-kuma-state" ]
      kumaConfig.systemd.services.uptime-kuma.preStart
  );
  units = map (db: "sqlite-backup-${db.name}.service") coreConfig.my.litestream.databases;
  jobs = [
    "tjoda"
    "ldn"
    "jotta"
  ];
in
assert kuma.StateDirectory == "uptime-kuma";
assert kuma.StateDirectoryMode == "2770";
assert coreConfig.users.users.uptime-kuma.homeMode == "2770";
assert kuma.UMask == "0007" && litestream.serviceConfig.UMask == "0007";
assert kuma.DynamicUser == false && kuma.User == "uptime-kuma" && kuma.Group == "uptime-kuma";
assert lib.elem "uptime-kuma" coreConfig.users.users.litestream.extraGroups;
assert lib.elem "uptime-kuma.service" litestream.after;
assert lib.elem "uptime-kuma.service" litestream.wants;
assert lib.all (rule: lib.elem rule coreConfig.systemd.tmpfiles.rules) [
  "z /var/lib/uptime-kuma 2770 uptime-kuma uptime-kuma - -"
  "z /var/lib/uptime-kuma/kuma.db 0660 uptime-kuma uptime-kuma - -"
  "z /var/lib/uptime-kuma/kuma.db-wal 0660 uptime-kuma uptime-kuma - -"
  "z /var/lib/uptime-kuma/kuma.db-shm 0660 uptime-kuma uptime-kuma - -"
];
assert lib.all (
  job:
  lib.all (
    unit:
    builtins.elem unit coreConfig.systemd.services."restic-backups-${job}".requires
    && builtins.elem unit coreConfig.systemd.services."restic-backups-${job}".after
  ) units
) jobs;
assert lib.all (
  job:
  lib.all (
    db:
    lib.all (path: builtins.elem path coreConfig.services.restic.backups.${job}.exclude) [
      db.path
      "${db.path}-wal"
      "${db.path}-shm"
    ]
  ) coreConfig.my.litestream.databases
) jobs;
pkgs.runCommand "backup-regressions"
  {
    passthru = { inherit kumaBootstrap; };
    nativeBuildInputs = with pkgs; [
      coreutils
      jq
      restic
      sqlite
      python3
      ruff
      pyright
      bubblewrap
    ];
  }
  ''
    set -euo pipefail
    cd "$TMPDIR"
    export RESTIC_REPOSITORY="$TMPDIR/repository"
    export RESTIC_PASSWORD=isolated-test-password
    export RESTIC_CACHE_DIR="$TMPDIR/cache"
    restic init
    mkdir required-state other-state
    echo required > required-state/data
    echo other > other-state/data
    backup() {
      ${guard} && restic backup required-state other-state
    }
    backup
    restic snapshots --json | jq -e 'length == 1'

    # Losing one source must fail even while another source is readable.
    mv required-state disappeared-state
    if backup; then
      echo "missing required source was accepted" >&2
      exit 1
    fi
    restic snapshots --json | jq -e 'length == 1'

    # Existing and dangling DynamicUser symlinks must both fail preflight.
    ln -s disappeared-state required-state
    if ${guard}; then exit 1; fi
    rm required-state
    ln -s absent-state required-state
    if ${guard}; then exit 1; fi
    ruff check --select ANN,UP,SIM,B,I --line-length 100 ${./permissions.py}
    ruff format --check --line-length 100 ${./permissions.py}
    echo '{"typeCheckingMode":"strict"}' > pyrightconfig.json
    pyright --pythonpath ${pkgs.python3}/bin/python3 --project pyrightconfig.json ${./permissions.py}
    python3 ${./permissions.py} ${kuma.StateDirectoryMode} ${kuma.UMask} ${litestream.serviceConfig.UMask} ${kumaBootstrap} --sandbox

    touch "$out"
  ''
