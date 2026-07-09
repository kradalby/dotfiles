{
  pkgs,
  lib,
  config,
  ...
}: {
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

  users.groups.proton = {};

  systemd.services.protonmail-bridge = {
    enable = true;
    description = "protonmail bridge";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

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

    path = [pkgs.pass pkgs.pass-secret-service pkgs.dbus];
  };

  # Tailscale Services configuration for Proton Bridge
  # Service must be pre-defined in Tailscale admin console at https://login.tailscale.com/admin/services
  services.tailscale.services.proton-bridge = {
    endpoints = {
      "tcp:25" = "tcp://127.0.0.1:1025"; # SMTP
      "tcp:143" = "tcp://127.0.0.1:1143"; # IMAP
    };
  };

  environment.systemPackages = [pkgs.protonmail-bridge];

  age.secrets.proton-imap-check = {
    file = ../../secrets/proton-imap-check.age;
  };

  # A signed-out bridge keeps its listeners up and passes any banner/TCP
  # check; an authenticated LOGIN is the only real "mail path works" signal.
  # Pushed to the pushgateway; staleness/0 is alerted on core.oracldn.
  systemd.services.proton-login-check = {
    description = "authenticated IMAP login probe of protonmail-bridge";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.age.secrets.proton-imap-check.path;
    };
    script = ''
      if ${pkgs.curl}/bin/curl -s --max-time 20 \
        --user "$PROTON_IMAP_USER:$PROTON_IMAP_PASSWORD" \
        "imap://127.0.0.1:1143/" >/dev/null; then
        ok=1
      else
        ok=0
      fi
      ${pkgs.curl}/bin/curl -s --max-time 30 --data-binary @- \
        "http://pushgateway/metrics/job/proton-bridge/instance/dev-oracfurt" <<EOF || true
      # TYPE proton_bridge_login_ok gauge
      proton_bridge_login_ok $ok
      EOF
    '';
  };

  systemd.timers.proton-login-check = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "30m";
      Persistent = true;
    };
  };
}
