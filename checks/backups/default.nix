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
in
pkgs.runCommand "backup-regressions"
  {
    nativeBuildInputs = with pkgs; [
      coreutils
      jq
      restic
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
    touch "$out"
  ''
