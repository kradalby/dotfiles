{
  lib,
  config,
}:
with lib;
with builtins; let
  # Host-centric IPAM configuration
  hosts = {
    "core.terra" = {
      site = "terra";
      gateway = "10.60.0.1";
      routes = {
        local = "10.60.0.0/16";
        ipv6_local = "2a03:94e0:200d::/48";
        openvpn = "10.60.200.0/24";
      };
      consul = "10.60.0.1";
      wireguard = {
        address = "10.69.0.200/32";
        ipv6_address = "2a03:94e0:200d:69::200/128";
      };
    };
    
    "dev.ldn" = {
      site = "ldn";
      gateway = "10.65.0.1";
      routes = {
        local = "10.65.0.0/16";
        ipv6_local = "2a02:6b66:7019::/64";
        openvpn = "10.65.200.0/24";
        iot_network = "192.168.156.0/24";
        microvm_bridge = "192.168.130.0/24";
      };
      consul = "10.65.0.1";
      wireguard = {
        address = "10.69.0.205/32";
        ipv6_address = "2a03:94e0:200d:69::205/128";
      };
    };
    
    "core.tjoda" = {
      site = "tjoda";
      gateway = "10.62.0.1";
      routes = {
        local = "10.62.0.0/16";
        openvpn = "10.62.200.0/24";
        microvm_bridge = "192.168.131.0/24";
      };
      consul = "10.62.0.1";
      wireguard = {
        address = "10.69.0.202/32";
      };
    };
    
    "core.oracldn" = {
      site = "oracldn";
      gateway = "10.66.0.1";
      routes = {
        local = "10.66.0.0/16";
        openvpn = "10.66.200.0/24";
      };
      consul = "10.66.0.1";
      wireguard = {
        address = "10.69.0.206/32";
        ipv6_address = "2a03:94e0:200d:69::206/128";
      };
    };
    
    "core.oracfurt" = {
      site = "oracfurt";
      gateway = "10.67.0.1";
      routes = {
        local = "10.67.0.0/16";
        openvpn = "10.67.200.0/24";
      };
      consul = "10.67.0.1";
      wireguard = {
        address = "10.69.0.207/32";
        ipv6_address = "2a03:94e0:200d:69::207/128";
      };
    };
  };

  # Derive sites from hosts for backward compatibility
  sites = 
    let
      hostsWithConsul = filterAttrs (hostname: host: hasAttr "consul" host) hosts;
      siteConfigs = mapAttrs (hostname: host: {
        name = host.site;
        nameservers = [host.gateway];
        consul = host.consul;
        openvpn = host.routes.openvpn;
        ipv4Gateway = host.gateway;
      }) hostsWithConsul;
    in
      # Re-key by site name instead of hostname
      listToAttrs (map (hostname: 
        let host = getAttr hostname hostsWithConsul;
        in nameValuePair host.site (getAttr hostname siteConfigs)
      ) (attrNames hostsWithConsul));

  # Legacy compatibility
  baseDomain = ".fap.no";
  currentSite = builtins.replaceStrings [baseDomain] [""] config.networking.domain;
  consulPeers = mapAttrs (key: value: value.consul) (filterAttrs (key: hasAttr "consul") (removeAttrs sites [currentSite]));
  consul = mapAttrs (key: value: value.consul) (filterAttrs (key: hasAttr "consul") sites);
  nameservers = lib.unique (lib.flatten (attrValues (mapAttrs (name: site: site.nameservers) sites)));

in {
  inherit hosts sites baseDomain currentSite consulPeers consul nameservers;
}