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

  services.pantalaimon-headless.instances.headscale = {
    logLevel = "debug";
    listenPort = 20662;
    homeserver = "https://matrix.org";
    extraSettings = {
      IgnoreVerification = true;
      UseKeyring = false;
    };
  };
}
