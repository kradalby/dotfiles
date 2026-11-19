{ config, ... }:
let
  domain = "umami.kradalby.no";
  port = 63458;
in
{
  imports = [ ./umami-sites.nix ];

  age.secrets.umami-app-secret.file = ../../secrets/umami-app-secret.age;

  services.umami = {
    enable = true;
    settings = {
      PORT = port;
      APP_SECRET_FILE = config.age.secrets.umami-app-secret.path;
      DISABLE_TELEMETRY = true;
    };
  };

  services.vhost."${domain}" = {
    proxyPass = "http://localhost:${toString port}";
    allowCors = false;
  };
}
