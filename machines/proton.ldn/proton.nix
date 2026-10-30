{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Setup:
  # su - proton
  # protonmail-bridge --cli

  users.users.proton = {
    home = "/var/lib/proton";
    createHome = true;
    group = "proton";
    isSystemUser = true;
    isNormalUser = false;
    description = "proton";
    shell = pkgs.bash;
  };

  users.groups.proton = { };

  systemd.services.protonmail-bridge = {
    enable = true;
    description = "protonmail bridge";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    script = "${lib.getExe pkgs.protonmail-bridge} --noninteractive --log-level debug";

    serviceConfig = {
      User = "proton";
      Group = "proton";
      Restart = "always";
      RestartSec = "15";
      WorkingDirectory = config.users.users.proton.home;
    };

    environment = {
      HOME = config.users.users.proton.home;
    };

    path = [
      pkgs.pass
      pkgs.pass-secret-service
      pkgs.dbus
    ];
  };

  # tailscaled terminates TLS with a real cert for the service name, so phones
  # get implicit-TLS IMAPS/SMTPS without trusting the bridge's self-signed
  # cert. The bridge accepts plaintext auth behind it while in STARTTLS mode.
  # Service object + grant: infrastructure/tailscale.
  services.tailscale.services.proton-bridge = {
    endpoints = {
      "tcp:465" = "tls-terminated-tcp://127.0.0.1:1025"; # SMTPS
      "tcp:993" = "tls-terminated-tcp://127.0.0.1:1143"; # IMAPS
    };
  };

  environment.systemPackages = [ pkgs.protonmail-bridge ];

  # Also the triage agents' pm-cli credential (see default.nix).
  age.secrets.proton-imap-check = {
    file = ../../secrets/proton-imap-check.age;
    owner = "kradalby";
  };

  # A signed-out bridge keeps its listeners up and passes any banner/TCP
  # check; an authenticated LOGIN is the only real "mail path works" signal.
  systemd.services.proton-login-check = {
    description = "authenticated IMAP login probe of protonmail-bridge";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.age.secrets.proton-imap-check.path;
    };
    script = ''
      # Credentials via curl's config-on-stdin (-K -), not argv: --user puts
      # them in the process list for the probe's lifetime.
      if ${pkgs.curl}/bin/curl -s --max-time 20 -K - \
        "imap://127.0.0.1:1143/" >/dev/null <<CFG; then
      user = "$PROTON_IMAP_USER:$PROTON_IMAP_PASSWORD"
      CFG
        ok=1
      else
        ok=0
      fi
      dir=/var/lib/prometheus-node-exporter-textfile
      tmp=$(mktemp "$dir/.proton-bridge.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      printf 'proton_bridge_login_ok %s\nproton_bridge_login_check_timestamp_seconds %s\n' \
        "$ok" "$(date +%s)" >"$tmp"
      chmod 0644 "$tmp"
      mv "$tmp" "$dir/proton-bridge.prom"
    '';
  };

  systemd.timers.proton-login-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Monotonic-only timer: Persistent= applies solely to OnCalendar and
      # was a no-op here.
      OnBootSec = "10m";
      OnUnitActiveSec = "30m";
    };
  };
}
