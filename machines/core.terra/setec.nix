{
  pkgs,
  lib,
  config,
  ...
}: {
  users.users.setec = {
    home = config.services.setec.dataDir;
    createHome = true;
    inherit (config.services.setec) group;
    isSystemUser = true;
    isNormalUser = false;
    description = "setec";
  };

  users.groups.setec = {};

  services.setec = {
    enable = true;
    kmsKeyName = "arn:aws:kms:eu-north-1:876457925437:key/de4daa6a-c38e-4f20-a532-8d4e814a6778";
    tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;
  };
}
