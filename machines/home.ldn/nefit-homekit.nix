{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common/tskey.nix
  ];

  age.secrets.nefit-homekit-env = {
    file = ../../secrets/nefit-homekit-env.age;
    mode = "0400";
    owner = "nefit-homekit";
  };

  services.nefit-homekit = {
    enable = true;
    package = pkgs.nefit-homekit;

    environmentFile = config.age.secrets.nefit-homekit-env.path;

    storagePath = "/var/lib/nefit-homekit";

    openFirewall = true;

    ports = {
      hap = 51826;
      web = 51827;
    };

    hapPin = "03145154";

    log = {
      level = "debug";
    };

    tailscale = {
      hostname = "nefit-homekit";
      authKeyFile = config.age.secrets.tailscale-preauthkey.path;
    };

    user = "nefit-homekit";
    group = "nefit-homekit";
  };
}
