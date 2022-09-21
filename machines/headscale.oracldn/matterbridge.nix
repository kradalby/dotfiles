{
  pkgs,
  lib,
  config,
  ...
}: {
  age.secrets.matterbridge-config = {
    owner = "matterbridge";
    file = ../../secrets/matterbridge-config.age;
  };

  services.matterbridge = {
    enable = true;
    configPath = config.age.secrets.matterbridge-config.path;
  };

  systemd.services.matterbridge.onFailure = ["notify-discord@%n.service"];
}
