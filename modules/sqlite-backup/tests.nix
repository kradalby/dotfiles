{ pkgs }:
let
  inherit (pkgs) lib;
  root = "/tmp/sqlite-backup-fixture";
  failingXZ = pkgs.writeShellScriptBin "xz" ''
    echo partial
    exit 43
  '';
  evaluate =
    packages:
    import (pkgs.path + "/nixos/lib/eval-config.nix") {
      system = pkgs.stdenv.hostPlatform.system;
      pkgs = packages;
      modules = [
        ./default.nix
        ./monitoring.nix
        {
          _module.args.pkgs = lib.mkForce packages;
          services.prometheus.exporters.node = {
            enable = true;
            enabledCollectors = [ "textfile" ];
            extraFlags = [ "--collector.textfile.directory=${root}/metrics ' quoted" ];
          };
          services.sqlite-backup = {
            fixture = {
              enable = true;
              databasePath = "${root}/source ' quoted.db";
              backupPath = "${root}/archives ' quoted";
              user = "root";
              group = "root";
              retention = "1day";
            };
            disabled.enable = false;
          };
        }
      ];
    };
  fixture = evaluate pkgs;
  script = pkgs.writeShellScript "sqlite-backup-fixture" fixture.config.systemd.services.sqlite-backup-fixture.script;
  failureScript =
    pkgs.writeShellScript "sqlite-backup-failure-fixture"
      (evaluate (pkgs // { xz = failingXZ; })).config.systemd.services.sqlite-backup-fixture.script;
  metricsCommand = builtins.head fixture.config.systemd.services.sqlite-backup-fixture.serviceConfig.ExecStopPost;
  rules = builtins.head fixture.config.services.prometheus.ruleFiles;

in
assert !(fixture.config.systemd.services ? sqlite-backup-disabled);
assert fixture.config.systemd.timers.sqlite-backup-fixture.timerConfig.OnCalendar == "hourly";
assert fixture.config.systemd.timers.sqlite-backup-fixture.timerConfig.Persistent;
assert
  fixture.config.services.sqlite-backup.fixture.monitoring.textfileDirectory
  == "${root}/metrics ' quoted";
assert
  fixture.config.systemd.services.sqlite-backup-fixture.serviceConfig.TimeoutStartSec == "30min";
pkgs.runCommand "sqlite-backup-regressions"
  {
    nativeBuildInputs = with pkgs; [
      coreutils
      fd
      pyright
      prometheus.cli
      python3
      restic
      ruff
      shellcheck
      sqlite
      xz
    ];
  }
  ''
    set -euo pipefail
    cp ${./tests.py} tests.py
    ruff check --select ANN,UP,SIM,B,I --target-version py312 tests.py
    ruff format --check --line-length 100 tests.py
    echo '{"typeCheckingMode":"strict","include":["tests.py"]}' > pyrightconfig.json
    pyright
    shellcheck ${script} ${failureScript} ${./metrics.sh}
    python ${./tests.py} ${
      lib.escapeShellArgs [
        (toString script)
        (toString failureScript)
        metricsCommand
        root
      ]
    }
    cp ${rules} sqlite-backup.rules.json
    cp ${./rules.test.yaml} rules.test.yaml
    promtool check rules sqlite-backup.rules.json
    promtool test rules rules.test.yaml
    cat "${root}/metrics ' quoted/"*.prom | promtool check metrics
    touch "$out"
  ''
