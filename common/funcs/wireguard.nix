{ config, ... }:
let
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

  service = name: secret: {
    sops.secrets.${secret} = { };
    networking.wireguard = {
      enable = true;
      interfaces = {
        wg0 = server name config.sops.secrets.${secret}.path;
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ config.networking.wireguard.interfaces.wg0.listenPort ];
      trustedInterfaces = [ "wg0" ];
    };
  };

in
{
  inherit service;
}

