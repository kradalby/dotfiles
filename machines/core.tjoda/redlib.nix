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

    tailscale.services.redlib = {
      endpoints."https:443" = "http://localhost:${toString config.services.redlib.port}";
    };
  };
}
