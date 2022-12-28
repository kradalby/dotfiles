{config, ...}: {
  age.secrets.golink-tskey = {
    file = ../../secrets/golink-tskey.age;
    owner = config.services.golink.user;
  };

  services.golink = {
    enable = true;
    tailscaleAuthKeyFile = config.age.secrets.golink-tskey.path;
    verbose = true;
  };
}
