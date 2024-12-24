{
  pkgs,
  lib,
  ...
}: {
  # services.protonmail-bridge.enable = true;

  systemd.services.protonmail-bridge = {
    enable = true;
    description = "protonmail bridge";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];

    script = "${lib.getExe pkgs.protonmail-bridge} --noninteractive --log-level debug";

    serviceConfig = {
      DynamicUser = true;
      Restart = "always";
      RestartSec = "15";
    };

    path = [pkgs.pass];
  };

  environment.systemPackages = [pkgs.protonmail-bridge pkgs.pass];
}
