{
  lib,
  config ? {},
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
  currentSite =
    let
      domain = lib.attrByPath ["networking" "domain"] "" config;
    in
      builtins.replaceStrings [baseDomain] [""] domain;
  consulPeers = mapAttrs (key: value: value.consul) (filterAttrs (key: hasAttr "consul") (removeAttrs sites [currentSite]));
  consul = mapAttrs (key: value: value.consul) (filterAttrs (key: hasAttr "consul") sites);
  nameservers = lib.unique (lib.flatten (attrValues (mapAttrs (name: site: site.nameservers) sites)));

  # Helper functions for network manipulation
  helpers = {
    # Extract network address from CIDR (e.g., "192.168.130.0/24" -> "192.168.130.0")
    getNetwork = cidr: lib.head (lib.splitString "/" cidr);

    # Extract prefix length from CIDR (e.g., "192.168.130.0/24" -> "24")
    getPrefixLength = cidr: lib.last (lib.splitString "/" cidr);

    # Extract network prefix without last octet (e.g., "192.168.130.0/24" -> "192.168.130")
    getNetworkPrefix = cidr: let
      network = lib.head (lib.splitString "/" cidr);
    in lib.concatStringsSep "." (lib.take 3 (lib.splitString "." network));

    # Build an IP address with a specific host part (e.g., "192.168.130.0/24", 1 -> "192.168.130.1")
    makeHostIP = cidr: host: let
      prefix = helpers.getNetworkPrefix cidr;
    in "${prefix}.${toString host}";

    # Build an IP address with CIDR notation (e.g., "192.168.130.0/24", 1 -> "192.168.130.1/24")
    makeHostIPWithCIDR = cidr: host: let
      prefix = helpers.getNetworkPrefix cidr;
      prefixLen = helpers.getPrefixLength cidr;
    in "${prefix}.${toString host}/${prefixLen}";
  };

in {
  inherit hosts sites baseDomain currentSite consulPeers consul nameservers helpers;
}
