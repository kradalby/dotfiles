{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
  ];

  # Shared homekit bridge key (tag:homekit, reusable — infra terraform).
  # Declared once here for all three bridges; root:0400, read via
  # LoadCredential by each bridge module.
  age.secrets.homekit-tskey.file = ../../secrets/homekit-tskey.age;

  age.secrets.nefit-homekit-env = {
    file = ../../secrets/nefit-homekit-env.age;
    mode = "0400";
    owner = "nefit-homekit";
  };

  services.nefit-homekit = {
    enable = true;
    package = pkgs.nefit-homekit;

    environmentFile = config.age.secrets.nefit-homekit-env.path;

    dataDir = "/var/lib/nefit-homekit";

    openFirewall = true;

    ports = {
      hap = 51826;
      web = 51827;
    };

    hapPin = "03145154";

    log.level = lib.mkForce "debug";

    tailscale = {
      hostname = "nefit-homekit";
      authKeyFile = config.age.secrets.homekit-tskey.path;
    };

    user = "nefit-homekit";
    group = "nefit-homekit";
  };
}
