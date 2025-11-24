{
  config,
  lib,
  ...
}:
with lib builtins; let
  s = import ../metadata/ipam.nix {inherit lib config;};
  peers = s.consulPeers;
  location = lib.elemAt (lib.splitString "." config.networking.domain) 0;
  serviceName = "svc:consul-${location}";
in {
  imports = [./consul.nix];
  config = {
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

    services.tailscale.services.${serviceName} = {
      endpoints = {
        "tcp:80" = "http://127.0.0.1:8500";
        "tcp:443" = "http://127.0.0.1:8500";
      };
    };
  };
}
