{ config, lib, ... }:
let
  consul = import ./consul.nix { inherit lib; };

  serverPeer = name:
    let
      wireguardHosts = import ../../metadata/wireguard.nix;
      wireguardConfig = wireguardHosts.servers."${name}";
    in
    {
      publicKey = wireguardConfig.public_key;
      allowedIPs = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
      endpoint = "${wireguardConfig.endpoint_address}:${toString wireguardConfig.endpoint_port}";
    };

  clientPeer = name:
    let
      wireguardHosts = import ../../metadata/wireguard.nix;
      wireguardConfig = wireguardHosts.clients."${name}";
    in
    {
      publicKey = wireguardConfig.public_key;
      allowedIPs = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
    };

  server = name: privateKeyPath:
    let
      wireguardHosts = import ../../metadata/wireguard.nix;
      wireguardConfig = wireguardHosts.servers."${name}";

      clients = map clientPeer (builtins.attrNames wireguardHosts.clients);

      # We need to filter out the current host
      servers = map serverPeer (builtins.filter (host: host != name) (builtins.attrNames wireguardHosts.servers));
    in
    {
      ips = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
      listenPort = wireguardConfig.endpoint_port;
      privateKeyFile = privateKeyPath;
      peers = servers ++ clients;
    };

  client = name: privateKeyPath:
    let
      wireguardHosts = import ../../metadata/wireguard.nix;
      wireguardConfig = wireguardHosts.clients."${name}";

      servers = map serverPeer (builtins.attrNames wireguardHosts.servers);
    in
    {
      ips = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
      privateKeyFile = privateKeyPath;
      peers = servers;
    };


  service = name: secret: wgConfig: {
    age.secrets.${secret}.file = ../../secrets + "/${secret}.age";
    networking.wireguard = {
      enable = true;
      interfaces = {
        wg0 = wgConfig;
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ config.networking.wireguard.interfaces.wg0.listenPort ];
      trustedInterfaces = [ "wg0" ];
    };

    services.prometheus.exporters.wireguard = {
      enable = true;
      # TODO: Remove when fixed upstream
      # withRemoteIp = true;
    };

    my.consulServices.wireguard_exporter = consul.prometheusExporter "wireguard" config.services.prometheus.exporters.wireguard.port;
  };

  clientService = name: secret:
    service name secret (client name config.age.secrets.${secret}.path);

  serverService = name: secret:
    service name secret (server name config.age.secrets.${secret}.path);
in
{
  inherit clientService serverService;
}
