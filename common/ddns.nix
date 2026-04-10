{
  config,
  lib,
  ...
}: let
  cfg = config.my.ddns;
in {
  options.my.ddns = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.domains != [ ];
        message = "my.ddns.domains must be set when my.ddns.enable is true.";
      }
    ];

    age.secrets.cloudflare-ddns-token = {
      mode = "0400";
      owner = "cloudflare-ddns";
      file = ../secrets/cloudflare-ddns-token.age;
    };

    services.cloudflare-ddns = {
      enable = true;
      credentialsFile = "/dev/null";
      domains = cfg.domains;
      provider = {
        ipv4 = "cloudflare.trace";
        ipv6 = "cloudflare.trace";
      };
      proxied = "false";
    };

    # The secret is a raw token, not KEY=VALUE env file format.
    # Use CLOUDFLARE_API_TOKEN_FILE to point at it directly.
    systemd.services.cloudflare-ddns.environment.CLOUDFLARE_API_TOKEN_FILE =
      config.age.secrets.cloudflare-ddns-token.path;
  };
}
