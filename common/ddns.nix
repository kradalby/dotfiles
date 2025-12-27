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
      file = ../secrets/cloudflare-token.age;
    };

    services.cloudflare-ddns = {
      enable = true;
      credentialsFile = config.age.secrets.cloudflare-ddns-token.path;
      domains = cfg.domains;
      provider = {
        ipv4 = "cloudflare.trace";
        ipv6 = "cloudflare.trace";
      };
      proxied = "false";
    };
  };
}
