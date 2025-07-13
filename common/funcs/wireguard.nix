{
  config,
  lib,
  pkgs,
  ...
}: let
  consul = import ./consul.nix {inherit lib;};

  routingTable = "main";

  serverPeer = netd: name: let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    wireguardConfig = wireguardHosts.servers."${name}";
  in
    if netd
    then {
      wireguardPeerConfig = {
        PublicKey = wireguardConfig.public_key;
        AllowedIPs = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
        Endpoint = "${wireguardConfig.endpoint_address}:${toString wireguardConfig.endpoint_port}";
        PersistentKeepalive = 25;
        RouteTable = routingTable;
      };
    }
    else {
      publicKey = wireguardConfig.public_key;
      allowedIPs = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
      endpoint = "${wireguardConfig.endpoint_address}:${toString wireguardConfig.endpoint_port}";
    };

  clientPeer = netd: name: let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    wireguardConfig = wireguardHosts.clients."${name}";
  in
    if netd
    then {
      wireguardPeerConfig = {
        PublicKey = wireguardConfig.public_key;
        AllowedIPs = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
        PersistentKeepalive = 25;
        RouteTable = routingTable;
      };
    }
    else {
      publicKey = wireguardConfig.public_key;
      allowedIPs = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
    };

  server = name: privateKeyPath: let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    wireguardConfig = wireguardHosts.servers."${name}";

    clients = map (clientPeer false) (builtins.attrNames wireguardHosts.clients);

    # We need to filter out the current host
    servers = map (serverPeer false) (builtins.filter (host: host != name) (builtins.attrNames wireguardHosts.servers));
  in {
    ips = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
    listenPort = wireguardConfig.endpoint_port;
    privateKeyFile = privateKeyPath;
    peers = servers ++ clients;
  };

  client = name: privateKeyPath: let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    wireguardConfig = wireguardHosts.clients."${name}";

    servers = map (serverPeer false) (builtins.attrNames wireguardHosts.servers);
  in {
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
      allowedUDPPorts = [config.networking.wireguard.interfaces.wg0.listenPort];
      trustedInterfaces = ["wg0"];
    };

    services.prometheus.exporters.wireguard = {
      enable = true;
      # TODO: Remove when fixed upstream
      # withRemoteIp = true;
    };

    my.consulServices.wireguard_exporter = consul.prometheusExporter "wireguard" config.services.prometheus.exporters.wireguard.port;
  };

  serviceNetworkD = name: secret: let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    all = wireguardHosts.servers // wireguardHosts.clients;
    wireguardConfig = all."${name}";

    clients = map (clientPeer true) (builtins.attrNames wireguardHosts.clients);

    # We need to filter out the current host
    servers = map (serverPeer true) (builtins.filter (host: host != name) (builtins.attrNames wireguardHosts.servers));
  in {
    age.secrets.${secret} = {
      file = ../../secrets + "/${secret}.age";
      mode = "0400";
      owner = "systemd-network";
    };

    environment.systemPackages = [pkgs.wireguard-tools];

    systemd.network = {
      enable = true;
      netdevs = {
        "50-wg0" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = "wg0";
            MTUBytes = "1300";
          };
          wireguardConfig = {
            PrivateKeyFile = config.age.secrets.${secret}.path;
            ListenPort = 51820;
          };
          wireguardPeers = servers ++ clients;
        };
      };
      networks."50-wg0" = {
        matchConfig.Name = "wg0";
        address = wireguardConfig.addresses ++ wireguardConfig.additional_networks;
        # address = lib.flatten (builtins.map (peer: peer.wireguardPeerConfig.AllowedIPs) (servers ++ clients));
        DHCP = "no";
        networkConfig = {
          IPMasquerade = "ipv4";
          IPv6AcceptRA = false;
        };
      };
    };

    networking.firewall = {
      trustedInterfaces = ["wg0"];
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
in {
  inherit clientService serverService serviceNetworkD;
}
