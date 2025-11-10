{
  pkgs,
  config,
  ...
}: let
  port = 56799;
in {
  # TODO: When Tailscale Services exits beta, use "http:80" and "https:443" instead of "tcp:"
  services.tailscale.services."svc:oppskrift" = {
    endpoints = {
      "tcp:80" = "http://localhost:${toString port}";
      "tcp:443" = "http://localhost:${toString port}";
    };
  };

  virtualisation = {
    oci-containers.containers = {
      mealie = {
        image = (import ../../metadata/versions.nix).mealie;
        autoStart = true;
        volumes = ["/var/lib/mealie/data:/app/data"];
        environment = {
          TZ = "Europa/Amsterdam";
          PUID = "1000";
          PGID = "1000";
          ALLOW_SIGNUP = "false";
          DB_ENGINE = "sqlite";
          BASE_URL = "oppskrift.dalby.ts.net";
          OIDC_AUTH_ENABLED = "true";
          OIDC_CONFIGURATION_URL = "https://idp.dalby.ts.net/.well-known/openid-configuration";
          OIDC_AUTO_REDIRECT = "true";
          OIDC_CLIENT_ID = "unused";
          OIDC_CLIENT_SECRET = "unused";
          OIDC_PROVIDER_NAME = "Tailscale";
          OIDC_NAME_CLAIM = "username";
        };
        ports = ["${toString port}:9000/tcp"];
      };
    };
  };
}
