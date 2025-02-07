{
  pkgs,
  config,
  ...
}: let
  port = 56799;
in {
  services = {
    tailscale-proxies = {
      mealie = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;

        hostname = "oppskrift";
        backendPort = port;
      };
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
