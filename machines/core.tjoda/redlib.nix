{
  config,
  lib,
  ...
}: {
  services = {
    redlib = {
      enable = true;
      port = 38080;
      address = "127.0.0.1";
    };
    tailscale-proxies = {
      redlib = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;

        hostname = "redlib";
        backendPort = config.services.redlib.port;
      };
    };
  };
}
