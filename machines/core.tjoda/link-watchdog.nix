# lan0 lost carrier at 01:14 on 2026-09-09 and the RTL8168f never renegotiated:
# no retry, no link-up, nothing from the driver for 6h40m, while the switch and
# cable stayed healthy. Only the PCI reset a reboot performs brought it back.
# Tjodalyng has no hands and no console, so recovery has to happen on the host.
#
# Escalates per episode: bounce the interface first, then reset the device on
# the bus. Acts only while carrier reads 0, so a healthy link is never touched.
# Counters live in /var/lib and are read after recovery — while the link is down
# nothing can scrape this host, so events are useless and counters are not.
{ pkgs, ... }:
let
  interface = "lan0";
  pciId = "0000:03:00.0";
  driverDir = "/sys/bus/pci/drivers/r8169";
  stateDir = "/var/lib/link-watchdog";
  textfileDir = "/var/lib/prometheus-node-exporter-textfile";

  # Ticks are one minute apart: bounce after 5 down, rebind from 10, then every
  # 5. `phase` makes each step fire once per episode even if a tick is missed.
  bounceAfter = 5;
  rebindAfter = 10;
  rebindEvery = 5;

  link-watchdog = pkgs.writeShellApplication {
    name = "link-watchdog";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.coreutils
    ];
    # Paths come from the environment so checks/link-watchdog can drive the same
    # script against a fake sysfs and a stub ip.
    text = ''
      iface="''${LW_IFACE:-${interface}}"
      pci="''${LW_PCI:-${pciId}}"
      driver_dir="''${LW_DRIVER_DIR:-${driverDir}}"
      state="''${LW_STATE:-${stateDir}}"
      out="''${LW_OUT:-${textfileDir}/link-watchdog.prom}"

      mkdir -p "$state" "$(dirname "$out")"

      get() { if [ -f "$state/$1" ]; then cat "$state/$1"; else echo "''${2:-0}"; fi; }
      put() { echo "$2" >"$state/$1"; }

      carrier_file="''${LW_CARRIER:-/sys/class/net/$iface/carrier}"
      carrier=0
      if [ -r "$carrier_file" ]; then
        carrier=$(cat "$carrier_file" 2>/dev/null || echo 0)
      fi

      down=$(get down_ticks)
      phase=$(get phase)
      lost=$(get lost_total)
      bounces=$(get bounce_total)
      rebinds=$(get rebind_total)
      recovered=$(get last_recovery)

      if [ "$carrier" = "1" ]; then
        if [ "$down" -gt 0 ]; then
          recovered=$(date +%s)
          put last_recovery "$recovered"
          echo "link-watchdog: $iface back up after $down min down" >&2
        fi
        down=0
        phase=0
      else
        # A 0 -> 0 run is the same episode; only the 1 -> 0 edge is a new one.
        if [ "$down" -eq 0 ]; then
          lost=$((lost + 1))
          put lost_total "$lost"
          echo "link-watchdog: $iface lost carrier" >&2
        fi
        down=$((down + 1))

        if [ "$down" -ge ${toString rebindAfter} ] &&
           { [ "$phase" -lt 2 ] || [ $((down % ${toString rebindEvery})) -eq 0 ]; }; then
          echo "link-watchdog: $iface still down after $down min, resetting $pci on the bus" >&2
          echo "$pci" >"$driver_dir/unbind" 2>/dev/null || true
          sleep 2
          echo "$pci" >"$driver_dir/bind" 2>/dev/null || true
          rebinds=$((rebinds + 1))
          put rebind_total "$rebinds"
          phase=2
        elif [ "$down" -ge ${toString bounceAfter} ] && [ "$phase" -eq 0 ]; then
          echo "link-watchdog: $iface down $down min, bouncing the interface" >&2
          ip link set "$iface" down || true
          sleep 2
          ip link set "$iface" up || true
          bounces=$((bounces + 1))
          put bounce_total "$bounces"
          phase=1
        fi
      fi

      put down_ticks "$down"
      put phase "$phase"

      tmp=$(mktemp "$out.XXXXXX")
      {
        echo "# HELP link_watchdog_carrier Carrier state of the watched interface (1 up, 0 down)."
        echo "# TYPE link_watchdog_carrier gauge"
        echo "link_watchdog_carrier{interface=\"$iface\"} $carrier"
        echo "# HELP link_watchdog_down_seconds How long carrier has been down in the current episode."
        echo "# TYPE link_watchdog_down_seconds gauge"
        echo "link_watchdog_down_seconds{interface=\"$iface\"} $((down * 60))"
        echo "# HELP link_watchdog_carrier_lost_total Carrier-loss episodes observed."
        echo "# TYPE link_watchdog_carrier_lost_total counter"
        echo "link_watchdog_carrier_lost_total{interface=\"$iface\"} $lost"
        echo "# HELP link_watchdog_bounce_total Interface down/up cycles performed."
        echo "# TYPE link_watchdog_bounce_total counter"
        echo "link_watchdog_bounce_total{interface=\"$iface\"} $bounces"
        echo "# HELP link_watchdog_rebind_total PCI unbind/bind cycles performed."
        echo "# TYPE link_watchdog_rebind_total counter"
        echo "link_watchdog_rebind_total{interface=\"$iface\"} $rebinds"
        echo "# HELP link_watchdog_last_recovery_seconds Unix time carrier last came back."
        echo "# TYPE link_watchdog_last_recovery_seconds gauge"
        echo "link_watchdog_last_recovery_seconds{interface=\"$iface\"} $recovered"
      } >"$tmp"
      chmod 0644 "$tmp"
      mv "$tmp" "$out"
    '';
  };
in
{
  systemd.services.link-watchdog = {
    description = "Recover ${interface} when carrier is lost, and export what it did";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${link-watchdog}/bin/link-watchdog";
      StateDirectory = "link-watchdog";
    };
  };

  systemd.timers.link-watchdog = {
    description = "Check ${interface} carrier every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
    };
  };
}
