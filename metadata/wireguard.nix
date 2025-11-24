{
  lib,
  config ? {},
}:
with lib;
with builtins; let
  ipam = import ./ipam.nix { inherit lib config; };

  # Generate WireGuard configs from IPAM hosts
  hostsToWireguard = mapAttrs (hostname: host: {
    additional_networks = attrValues (filterAttrs (name: cidr:
      name != "microvm_bridge" && name != "iot_network"
    ) host.routes);
    addresses =
      if hasAttr "ipv6_address" host.wireguard
      then [host.wireguard.address host.wireguard.ipv6_address]
      else [host.wireguard.address];
    dns =
      if hasAttr "consul" host && host.consul != null
      then host.consul
      else null;
  }) ipam.hosts;

in {
  servers = {
    oracleldn = hostsToWireguard."core.oracldn" // {
      endpoint_address = "oracldn.fap.no";
      endpoint_port = 51820;
      public_key = "Gp4ZxbTOP3yo8SVPBC1Bi34OqArGYsvP3MNT1CjbTyM=";
    };

    oraclefurt = hostsToWireguard."core.oracfurt" // {
      endpoint_address = "oracfurt.fap.no";
      endpoint_port = 51820;
      public_key = "3cjdc90xSHcs+E9lY1LoLavsWumxyNtsfCVuLWKHglw=";
    };

    terra = hostsToWireguard."core.terra" // {
      endpoint_address = "terra.fap.no";
      endpoint_port = 51820;
      public_key = "c/PM40me7sWgdYyXTMCTV3KXuRvCvpQzIW5AK4w+fDY=";
    };

    tjoda = hostsToWireguard."core.tjoda" // {
      endpoint_address = "tjoda.fap.no";
      endpoint_port = 51820;
      public_key = "sZ6JQB3ud/NxyxrEiTBe6MkoTU4BTpaYz4lvboAq8AQ=";
    };
  };

  clients = {
    ldn = hostsToWireguard."dev.ldn" // {
      # endpoint_address = "ldn.fap.no";
      # endpoint_port = 51820;
      public_key = "L1sF/PWHXiavT2arPLhDyh9wWwK5a3UeC4mpvFG8xFE=";
    };

    kramacbook = {
      additional_networks = [];
      addresses = ["10.69.0.1/32" "2a03:94e0:200d:69::1/128"];
      public_key = "A2hlNqjakhcYw+d40FQYUrMbnRN6KfL/ZhNAzuNoSjY=";
    };

    storagebassan = {
      additional_networks = [];
      addresses = ["10.69.0.16/32" "2a03:94e0:200d:69::16/128"];
      public_key = "nL309b5ZosnRKL0xGiNuCln9q5FqA8UGdot54C2ioy0=";
    };

    headscale = {
      additional_networks = [];
      addresses = ["10.69.0.9/32" "2a03:94e0:200d:69::9/128"];
      public_key = "tuiPc7znUC4vAFJhmbsVuenGBGY+Y4WgVxGrVUl6/wk=";
    };
  };
}
