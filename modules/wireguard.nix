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
  peerKeysForRefresh =
    if cfg.refreshOnIdle.enable
    then map (name: peers.${name}.public_key) cfg.refreshOnIdle.peers
    else [];

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

    refreshOnIdle = {
      enable = mkEnableOption "Refresh WireGuard when selected peers are idle too long";

      peers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Peer names from metadata/wireguard.nix to watch for idle handshakes.";
      };

      maxAgeSeconds = mkOption {
        type = types.int;
        default = 21600;
        description = "Max allowed time since latest handshake before refreshing.";
      };

      interval = mkOption {
        type = types.str;
        default = "30min";
        description = "Systemd timer interval between refresh checks.";
      };
    };

    refreshDaily = {
      enable = mkEnableOption "Refresh WireGuard once per day";

      onCalendar = mkOption {
        type = types.str;
        default = "daily";
        description = "Systemd OnCalendar expression for daily refresh.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.refreshOnIdle.enable -> all (name: hasAttr name peers) cfg.refreshOnIdle.peers;
        message = "services.wireguard.refreshOnIdle.peers must reference peers from metadata/wireguard.nix for ${cfg.nodeName}.";
      }
    ];

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

    systemd.services."wireguard-refresh-${cfg.interface}" = mkIf cfg.refreshOnIdle.enable {
      description = "Refresh WireGuard config for ${cfg.interface} when peers are idle";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        set -euo pipefail

        wg_bin="${pkgs.wireguard-tools}/bin/wg"
        networkctl_bin="${pkgs.systemd}/bin/networkctl"
        date_bin="${pkgs.coreutils}/bin/date"

        now="$("$date_bin" +%s)"
        threshold="${toString cfg.refreshOnIdle.maxAgeSeconds}"
        watch_keys=(${concatStringsSep " " (map escapeShellArg peerKeysForRefresh)})

        if [ "''${#watch_keys[@]}" -eq 0 ]; then
          exit 0
        fi

        reload=0
        while read -r key ts; do
          for watch in "''${watch_keys[@]}"; do
            if [ "$key" = "$watch" ]; then
              if [ "$ts" = "0" ]; then
                reload=1
              else
                age=$((now - ts))
                if [ "$age" -ge "$threshold" ]; then
                  reload=1
                fi
              fi
            fi
          done
        done < <("$wg_bin" show ${cfg.interface} latest-handshakes)

        if [ "$reload" -eq 1 ]; then
          "$networkctl_bin" reconfigure ${cfg.interface}
        fi
      '';
      wantedBy = ["multi-user.target"];
    };

    systemd.timers."wireguard-refresh-${cfg.interface}" = mkIf cfg.refreshOnIdle.enable {
      wantedBy = ["timers.target"];
      partOf = ["wireguard-refresh-${cfg.interface}.service"];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.refreshOnIdle.interval;
      };
    };

    systemd.services."wireguard-refresh-daily-${cfg.interface}" = mkIf cfg.refreshDaily.enable {
      description = "Refresh WireGuard config for ${cfg.interface} daily";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        ${pkgs.systemd}/bin/networkctl reconfigure ${cfg.interface}
      '';
      wantedBy = ["multi-user.target"];
    };

    systemd.timers."wireguard-refresh-daily-${cfg.interface}" = mkIf cfg.refreshDaily.enable {
      wantedBy = ["timers.target"];
      partOf = ["wireguard-refresh-daily-${cfg.interface}.service"];
      timerConfig.OnCalendar = cfg.refreshDaily.onCalendar;
    };
  };
}
