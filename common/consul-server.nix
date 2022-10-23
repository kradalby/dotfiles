{
  config,
  lib,
  ...
}:
with lib builtins; let
  nginx = import ./funcs/nginx.nix {inherit config lib;};

  domain = "consul.${config.networking.domain}";

  s = import ../metadata/sites.nix {inherit lib config;};
  peers = s.consulPeers;
in {
  imports = [./consul.nix];
  config = lib.mkMerge [
    {
      services.consul = {
        enable = true;
        webUi = true;

        extraConfig = {
          server = true;
          bootstrap = true;

          bind_addr = ''{{ GetInterfaceIP "${config.my.lan}" }}'';

          retry_join = [];
          retry_join_wan = builtins.attrValues peers;

          connect = {
            enabled = true;
          };
        };
      };
    }

    (nginx.internalVhost {
      inherit domain;
      proxyPass = "http://127.0.0.1:8500";
    })
  ];
}
