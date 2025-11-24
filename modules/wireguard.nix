{ config, lib, pkgs, ... }:

with lib;

let
  inherit (builtins) attrNames filter;

  cfg = config.services.wireguard.instances;

  consul = import ../common/funcs/consul.nix { inherit lib; };
  wireguardHosts = import ../metadata/wireguard.nix { inherit lib config; };

  routingTableDefault = "main";

  serverPeer = netd: name:
    let
      peerCfg = wireguardHosts.servers.${name};
      addrList = peerCfg.addresses ++ peerCfg.additional_networks;
      endpoint = "${peerCfg.endpoint_address}:${toString peerCfg.endpoint_port}";
    in
      if netd then {
        PublicKey = peerCfg.public_key;
        AllowedIPs = addrList;
        Endpoint = endpoint;
        PersistentKeepalive = 25;
        RouteTable = routingTableDefault;
      } else {
        publicKey = peerCfg.public_key;
        allowedIPs = addrList;
        endpoint = endpoint;
      };

  clientPeer = netd: name:
    let
      peerCfg = wireguardHosts.clients.${name};
      addrList = peerCfg.addresses ++ peerCfg.additional_networks;
    in
      if netd then {
        PublicKey = peerCfg.public_key;
        AllowedIPs = addrList;
        PersistentKeepalive = 25;
        RouteTable = routingTableDefault;
      } else {
        publicKey = peerCfg.public_key;
        allowedIPs = addrList;
      };

  serverInterface = name: privateKeyPath:
    let
      serverCfg = wireguardHosts.servers.${name};
      clients = map (clientPeer false) (attrNames wireguardHosts.clients);
      peerServers = map (serverPeer false) (filter (peer: peer != name) (attrNames wireguardHosts.servers));
    in {
      ips = serverCfg.addresses ++ serverCfg.additional_networks;
      listenPort = serverCfg.endpoint_port;
      privateKeyFile = privateKeyPath;
      peers = peerServers ++ clients;
    };

  clientInterface = name: privateKeyPath:
    let
      clientCfg = wireguardHosts.clients.${name};
      servers = map (serverPeer false) (attrNames wireguardHosts.servers);
    in {
      ips = clientCfg.addresses ++ clientCfg.additional_networks;
      privateKeyFile = privateKeyPath;
      peers = servers;
    };

  buildKernelConfig = instanceCfg: secretPath:
    let
      ifaceCfg =
        if instanceCfg.role == "server"
        then serverInterface instanceCfg.node secretPath
        else clientInterface instanceCfg.node secretPath;
      ifaceName = instanceCfg.interface;
      allowedPorts =
        optionals (ifaceCfg ? listenPort && ifaceCfg.listenPort != null) [
          ifaceCfg.listenPort
        ];
    in {
      networking.wireguard.enable = true;
      networking.wireguard.interfaces.${ifaceName} = ifaceCfg;

      networking.firewall.allowedUDPPorts = allowedPorts;
      networking.firewall.trustedInterfaces = [ ifaceName ];
    };

  buildNetworkdConfig = instanceCfg: hostCfg: secretPath:
    let
      ifaceName = instanceCfg.interface;
      unitName = instanceCfg.networkdUnitName;
      listenPort =
        if instanceCfg.listenPort != null then instanceCfg.listenPort
        else if instanceCfg.role == "server" && hostCfg ? endpoint_port then hostCfg.endpoint_port
        else 51820;

      clients = map (clientPeer true) (attrNames wireguardHosts.clients);
      servers = map (serverPeer true) (filter (peer: peer != instanceCfg.node) (attrNames wireguardHosts.servers));
    in {
      environment.systemPackages = [ pkgs.wireguard-tools ];

      systemd.network = {
        enable = true;

        netdevs.${unitName} = {
          netdevConfig = {
            Kind = "wireguard";
            Name = ifaceName;
            MTUBytes = toString instanceCfg.mtu;
          };
          wireguardConfig = {
            PrivateKeyFile = secretPath;
            ListenPort = listenPort;
          };
          wireguardPeers = servers ++ clients;
        };

        networks.${unitName} = {
          matchConfig.Name = ifaceName;
          address = hostCfg.addresses ++ hostCfg.additional_networks;
          DHCP = "no";
          networkConfig = {
            IPMasquerade = "ipv4";
            IPv6AcceptRA = false;
          };
        };
      };

      networking.firewall.trustedInterfaces = [ ifaceName ];
    };

  buildInstance = name: instanceCfg:
    let
      nodeName = instanceCfg.node;
      hostCfg =
        if instanceCfg.role == "server"
        then attrByPath [nodeName] null wireguardHosts.servers
        else attrByPath [nodeName] null wireguardHosts.clients;
    in
      if !instanceCfg.enable then {
        assertions = [];
        secrets = {};
        config = {};
      } else if hostCfg == null then {
        assertions = [
          {
            assertion = false;
            message = "services.wireguard.instances.${name}: unable to find ${instanceCfg.role} `${nodeName}` in metadata/wireguard.nix";
          }
        ];
        secrets = {};
        config = {};
      } else
        let
          baseSecretAttrs = {
            file = ../secrets + "/${instanceCfg.secret}.age";
          };
          secretAttrs =
            baseSecretAttrs
            // optionalAttrs (instanceCfg.secretOwner != null) {
              owner = instanceCfg.secretOwner;
            }
            // optionalAttrs (instanceCfg.secretMode != null) {
              mode = instanceCfg.secretMode;
            }
            // optionalAttrs (instanceCfg.secretOwner == null && instanceCfg.backend == "networkd") {
              owner = "systemd-network";
            }
            // optionalAttrs (instanceCfg.secretMode == null && instanceCfg.backend == "networkd") {
              mode = "0400";
            };
          secretPath = config.age.secrets.${instanceCfg.secret}.path;
          configFragment =
            if instanceCfg.backend == "networkd"
            then buildNetworkdConfig instanceCfg hostCfg secretPath
            else buildKernelConfig instanceCfg secretPath;
        in {
          assertions = [];
          secrets = {
            "${instanceCfg.secret}" = secretAttrs;
          };
          config = configFragment;
        };

  instanceResults = mapAttrsToList buildInstance cfg;

  configFragments = map (result: result.config) instanceResults;
  mergedConfig =
    if configFragments == []
    then {}
    else mkMerge configFragments;

  secretFragments = map (result: result.secrets) instanceResults;
  mergedSecrets =
    if secretFragments == []
    then {}
    else mkMerge secretFragments;

  allAssertions = concatMap (result: result.assertions) instanceResults;

  exporterEnabled = any (instanceCfg: instanceCfg.enable && instanceCfg.exporter) (attrValues cfg);
in {
  options.services.wireguard.instances = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        enable = mkEnableOption "WireGuard configuration ${name}";

        node = mkOption {
          type = types.str;
          default = name;
          description = mdDoc "Attribute name under metadata/wireguard.nix for this WireGuard endpoint.";
        };

        role = mkOption {
          type = types.enum ["server" "client"];
          default = "server";
          description = mdDoc "Lookup the node under either `servers` or `clients`.";
        };

        backend = mkOption {
          type = types.enum ["kernel" "networkd"];
          default = "kernel";
          description = mdDoc "Use kernel networking (networking.wireguard) or systemd-networkd netdevs.";
        };

        interface = mkOption {
          type = types.str;
          default = "wg0";
          description = mdDoc "Interface name for the WireGuard link.";
        };

        networkdUnitName = mkOption {
          type = types.str;
          default = "50-${name}";
          description = mdDoc "Unit prefix used when backend=networkd.";
        };

        mtu = mkOption {
          type = types.int;
          default = 1300;
          description = mdDoc "MTU for networkd deployments.";
        };

        listenPort = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = mdDoc "Optional override for the listen port.";
        };

        secret = mkOption {
          type = types.str;
          description = mdDoc "Name of the age secret that stores the WireGuard private key.";
        };

        secretOwner = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = mdDoc "Override the owner of the secret file.";
        };

        secretMode = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = mdDoc "Override the mode (string) set on the secret file.";
        };

        exporter = mkOption {
          type = types.bool;
          default = true;
          description = mdDoc "Enable the Prometheus exporter and Consul service.";
        };
      };
    }));
    default = {};
    description = mdDoc ''
      Declarative WireGuard interfaces backed by metadata/wireguard.nix.
      Each entry provisions the secret and wires up peers automatically.
    '';
  };

  config =
    mergedConfig
    // {
      assertions = allAssertions;
      age.secrets = mergedSecrets;
    }
    // mkIf exporterEnabled {
      services.prometheus.exporters.wireguard.enable = true;
      my.consulServices.wireguard_exporter =
        consul.prometheusExporter "wireguard" config.services.prometheus.exporters.wireguard.port;
    };
}
