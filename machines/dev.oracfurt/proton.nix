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

  environment.systemPackages = [pkgs.protonmail-bridge];
}
