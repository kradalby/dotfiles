{
  config,
  pkgs,
  lib,
  ...
}: let
  # The sfiber proxies join a FOREIGN headscale net that Prometheus cannot
  # reach, and their units run Restart=always, so an expired preauth key or a
  # dead control server leaves them "active" but non-functional forever with no
  # alert able to see it. This oneshot closes that gap by pushing a per-proxy
  # gauge to the fleet pushgateway; a proxy that is down still gets pushed as 0
  # (that 0 is the whole signal), and PushgatewayGroupStale catches the timer
  # itself dying.
  # Enumerate the tailscale-proxy instances straight from config (currently
  # restic-sfiber + minio-sfiber) so the check tracks whatever proxies exist
  # rather than a hardcoded, drift-prone list.
  proxyNames =
    lib.attrNames (lib.filterAttrs (_: p: p.enable) config.services.tailscale-proxies);

  pushgateway = "http://pushgateway/metrics/job/sfiber-proxy/instance/core-tjoda";

  # proxy-to-grafana is a tsnet app: its local API is an in-memory memnet
  # listener, not an on-disk socket, so `tailscale --socket ... status` cannot
  # reach it. The only host-observable backend-state signal is tsnet's own
  # "Switching ipn state <from> -> <to>" log line (ipnlocal), which lands in
  # journald. We treat a proxy as up iff its unit is active and its most recent
  # backend-state transition reached Running. A steadily-Running proxy whose
  # transition line has aged out of the journal reports up as well, so retention
  # gaps fail safe (no false alert); a stuck/never-logged-in proxy keeps logging
  # NeedsLogin and reports down.
  journalctl = "${config.systemd.package}/bin/journalctl";
  systemctl = "${config.systemd.package}/bin/systemctl";
in {
  systemd.services.sfiber-proxy-check = {
    description = "Push sfiber tailscale-proxy liveness to the fleet pushgateway";
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig.Type = "oneshot";

    script = ''
      set -uo pipefail

      lines=('# TYPE sfiber_proxy_up gauge')
      for proxy in ${lib.escapeShellArgs proxyNames}; do
        unit="tailscale-proxy-$proxy"
        up=0
        if ${systemctl} is-active --quiet "$unit"; then
          state=$(${journalctl} -u "$unit" --output=cat --no-pager 2>/dev/null \
            | ${pkgs.gnugrep}/bin/grep -oE 'Switching ipn state [A-Za-z]+ -> [A-Za-z]+' \
            | ${pkgs.coreutils}/bin/tail -n1 \
            | ${pkgs.gnugrep}/bin/grep -oE '[A-Za-z]+$' || true)
          if [ -z "$state" ] || [ "$state" = "Running" ]; then
            up=1
          fi
        fi
        lines+=("sfiber_proxy_up{proxy=\"$proxy\"} $up")
      done

      # Always push, even when a proxy is down; only a failed push is an error.
      printf '%s\n' "''${lines[@]}" \
        | ${pkgs.curl}/bin/curl -sS --fail --data-binary @- ${lib.escapeShellArg pushgateway}
      exit $?
    '';
  };

  systemd.timers.sfiber-proxy-check = {
    wantedBy = ["timers.target"];
    partOf = ["sfiber-proxy-check.service"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
    };
  };
}
