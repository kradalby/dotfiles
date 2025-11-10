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
  services.tailscale.services = {
    "svc:proton-bridge" = {
      endpoints = {
        "tcp:25" = "tcp://127.0.0.1:1025";   # SMTP with TLS
        "tcp:143" = "tcp://127.0.0.1:1143";  # IMAP with TLS
      };
    };
  };

  environment.systemPackages = [pkgs.protonmail-bridge];
}
