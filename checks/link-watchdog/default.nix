# Drives the deployed link-watchdog script — reached through core.tjoda's unit,
# so this tests the real thing, not a copy — against a fake carrier file, a fake
# driver directory and a scratch state dir.
#
# The escalation ladder is a counter and two thresholds, and it only ever runs
# when nobody is watching, so it gets a test. `ip` genuinely fails here (no such
# interface, no netlink in the sandbox) and is meant to: the script must keep
# going and still account for what it tried.
{ pkgs, self }:
let
  execStart =
    self.nixosConfigurations."core.tjoda".config.systemd.services.link-watchdog.serviceConfig.ExecStart;
in
pkgs.runCommand "link-watchdog-test" { nativeBuildInputs = [ pkgs.coreutils ]; } ''
  set -eu
  root=$TMPDIR/lw
  mkdir -p "$root/state" "$root/driver"
  : >"$root/driver/unbind"
  : >"$root/driver/bind"

  export LW_IFACE=lwtest0
  export LW_PCI=0000:03:00.0
  export LW_CARRIER="$root/carrier"
  export LW_DRIVER_DIR="$root/driver"
  export LW_STATE="$root/state"
  export LW_OUT="$root/link-watchdog.prom"

  tick() { ${execStart} 2>>"$root/log" || { echo "FAIL: watchdog exited non-zero"; exit 1; }; }
  metric() { grep -oP "(?<=^$1\{interface=\"lwtest0\"\} ).*" "$LW_OUT"; }
  expect() {
    got=$(metric "$1")
    if [ "$got" != "$2" ]; then
      echo "FAIL: $1 expected $2, got $got"
      cat "$LW_OUT"
      exit 1
    fi
  }

  # A healthy link is never touched.
  echo 1 >"$root/carrier"
  tick
  expect link_watchdog_carrier 1
  expect link_watchdog_down_seconds 0
  expect link_watchdog_carrier_lost_total 0
  expect link_watchdog_bounce_total 0

  # Carrier dies. One episode, no action before the 5-minute threshold.
  echo 0 >"$root/carrier"
  for _ in 1 2 3 4; do tick; done
  expect link_watchdog_carrier_lost_total 1
  expect link_watchdog_down_seconds 240
  expect link_watchdog_bounce_total 0

  # Fifth tick bounces the interface, once.
  tick
  expect link_watchdog_bounce_total 1
  tick
  expect link_watchdog_bounce_total 1

  # Tenth tick escalates to a bus-level reset, and the PCI id really is written.
  for _ in 1 2 3 4; do tick; done
  expect link_watchdog_rebind_total 1
  if ! grep -q "$LW_PCI" "$root/driver/unbind"; then
    echo "FAIL: PCI id was never written to unbind"
    exit 1
  fi
  if ! grep -q "$LW_PCI" "$root/driver/bind"; then
    echo "FAIL: PCI id was never written to bind"
    exit 1
  fi

  # Recovery clears the episode and stamps the time.
  echo 1 >"$root/carrier"
  tick
  expect link_watchdog_carrier 1
  expect link_watchdog_down_seconds 0
  if [ "$(metric link_watchdog_last_recovery_seconds)" = "0" ]; then
    echo "FAIL: recovery timestamp not recorded"
    exit 1
  fi

  # A later loss is a new episode, and the ladder starts over.
  echo 0 >"$root/carrier"
  for _ in 1 2 3 4 5; do tick; done
  expect link_watchdog_carrier_lost_total 2
  expect link_watchdog_bounce_total 2

  touch $out
''
