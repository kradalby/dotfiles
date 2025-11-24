{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wireguard;
  wireguardHosts = import ../metadata/wireguard.nix { inherit lib config; };
  
  # Helper to find the node configuration in metadata
  nodeConfig = 
    if hasAttr cfg.nodeName wireguardHosts.servers then
      wireguardHosts.servers.${cfg.nodeName} // { role = "server"; }
    else if hasAttr cfg.nodeName wireguardHosts.clients then
      wireguardHosts.clients.${cfg.nodeName} // { role = "client"; }
    else
      throw "WireGuard node '${cfg.nodeName}' not found in metadata/wireguard.nix";

  isServer = nodeConfig.role == "server";

  # Determine peers based on role
  # Servers peer with all other servers and all clients
  # Clients peer with all servers
  
  serverPeers = filterAttrs (n: v: n != cfg.nodeName) wireguardHosts.servers;
  clientPeers = wireguardHosts.clients; # Clients don't peer with other clients usually, but servers need to know about them

  peers = 
    if isServer then
      serverPeers // clientPeers
    else
      wireguardHosts.servers;

  # Function to convert a peer definition to systemd.network config
  mkPeer = name: peer: {
    PublicKey = peer.public_key;
    AllowedIPs = peer.addresses ++ (peer.additional_networks or []);
    Endpoint = if hasAttr "endpoint_address" peer then "${peer.endpoint_address}:${toString peer.endpoint_port}" else null;
    PersistentKeepalive = 25;
    # RouteTable = "main"; # Default is main, usually fine
  };

  peerList = mapAttrsToList mkPeer peers;

  # Secret handling
  secretName = "wireguard-${cfg.nodeName}";
  secretFile = ../secrets + "/${secretName}.age";

in {
  options.services.wireguard = {
    enable = mkEnableOption "WireGuard";

    nodeName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Name of the node in metadata/wireguard.nix";
    };

    secretName = mkOption {
      type = types.str;
      default = "wireguard-${cfg.nodeName}";
      description = "Name of the age secret file (without .age extension)";
    };
    
    interface = mkOption {
      type = types.str;
      default = "wg0";
      description = "Interface name";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.wireguard-tools ];

    age.secrets.${cfg.secretName} = {
      file = ../secrets + "/${cfg.secretName}.age";
      owner = "systemd-network";
      mode = "0400";
    };

    systemd.network = {
      enable = true;
      
      netdevs."50-${cfg.interface}" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = cfg.interface;
          MTUBytes = "1300"; # Standardize MTU
        };
        wireguardConfig = {
          PrivateKeyFile = "/run/agenix/${cfg.secretName}";
          ListenPort = if isServer then nodeConfig.endpoint_port else 51820;
        };
        wireguardPeers = peerList;
      };

      networks."50-${cfg.interface}" = {
        matchConfig.Name = cfg.interface;
        address = nodeConfig.addresses;
        DHCP = "no";
        networkConfig = {
          IPMasquerade = "ipv4";
          IPv6AcceptRA = false;
        };
      };
    };

    networking.firewall = {
      trustedInterfaces = [ cfg.interface ];
      allowedUDPPorts = optionals isServer [ nodeConfig.endpoint_port ];
    };
  };
}
