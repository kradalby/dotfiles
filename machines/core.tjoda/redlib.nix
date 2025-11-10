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

    tailscale.services."svc:redlib" = {
      endpoints."tcp:443" = "http://localhost:${toString config.services.redlib.port}";
    };
  };
}
