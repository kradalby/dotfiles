{
  lib,
  config,
  ...
}:
with lib;
with builtins; let
  ipam = import ../../metadata/ipam.nix {inherit lib config;};
  host = ipam.hosts."core.tjoda";
in {
  # Override microvm bridge to use IPAM-defined range
  systemd.network.networks."microvm-br0".addresses = lib.mkForce [
    {
      Address = "192.168.131.1/24";  # From host.routes.microvm_bridge
    }
    {
      Address = "fd12:3456:789b::1/64";
    }
  ];
}
