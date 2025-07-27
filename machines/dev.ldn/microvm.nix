{
  lib,
  config,
  ...
}:
with lib;
with builtins; let
  ipam = import ../../metadata/ipam.nix {inherit lib config;};
  host = ipam.hosts."dev.ldn";
in {
  # Override microvm bridge to use IPAM-defined range
  systemd.network.networks."microvm-br0" = {
    addresses = lib.mkForce [
      {
        Address = ipam.helpers.makeHostIPWithCIDR host.routes.microvm_bridge 1;
      }
      {
        Address = "fd12:3456:789a::1/64";
      }
    ];
    # Disable systemd-networkd DHCPServer since we use dnsmasq
    networkConfig = {
      DHCPServer = lib.mkForce false;
    };
  };
}