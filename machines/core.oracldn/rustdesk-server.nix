{
  config,
  pkgs,
  lib,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};
  domain = "desk.kradalby.no";
in {
  imports = [../../modules/rustdesk-server.nix];

  config = lib.mkMerge [
    {
      age.secrets.rustdesk = {
        file = ../../secrets/rustdesk-ed25519.age;
        owner = "rustdesk-server";
      };

      age.secrets.rustdesk-pub = {
        file = ../../secrets/rustdesk-ed25519-pub.age;
        owner = "rustdesk-server";
      };

      users.users.rustdesk-server = {
        home = "/var/lib/rustdesk-server";
        createHome = true;
        group = "rustdesk-server";
        isSystemUser = true;
        isNormalUser = false;
        description = "rustdesk-server";
      };

      users.groups.rustdesk-server = {};

      services."rustdesk-server" = {
        enable = true;
        openFirewall = true;

        pubKeyFile = config.age.secrets.rustdesk-pub.path;
        privKeyFile = config.age.secrets.rustdesk.path;

        inherit domain;
      };
    }

    (nginx.internalVhost {
      inherit domain;
      proxyPass = "http://127.0.0.1:21117";
      tailscaleAuth = false;
    })
  ];
}
