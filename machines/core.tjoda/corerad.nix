{
  config,
  lib,
  ...
}: let
  consul = import ../../common/funcs/consul.nix {inherit lib;};
in {
  services.corerad = {
    enable = true;
    settings = {
      interfaces =
        # Upstream monitoring interfaces.
        lib.forEach [config.my.wan]
        (ifi: {
          name = ifi;
          monitor = true;
        })
        # Downstream advertising interfaces.
        ++ lib.forEach [config.my.lan "selskap"]
        (ifi: {
          name = ifi;
          advertise = true;

          # Advertise all /64 prefixes on the interface.
          prefix = [{}];

          # Automatically use the appropriate interface address as a DNS server.
          rdnss = [{}];
        });
      # Optionally enable Prometheus metrics.
      debug = {
        address = ":9430";
        prometheus = true;
      };
    };
  };

  networking.firewall.interfaces.enp1s0f0.allowedTCPPorts = [9430];

  my.consulServices.corerad_exporter = consul.prometheusExporter "corerad" 9430;
}
