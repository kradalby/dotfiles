{ config, lib, inputs, ... }:

{
  imports = [ inputs.microvm.nixosModules.host ];

  microvm.host.enable = true;

  systemd.network = {
    enable = true;
    # MicroVM bridge for isolated container networking
    # Provides dedicated network segment for MicroVMs separate from host LAN
    netdevs."microvm-br0".netdevConfig = {
      Kind = "bridge";
      Name = "microvm-br0";
    };
    networks."microvm-br0" = {
      matchConfig.Name = "microvm-br0";
      addresses = [
        {
          Address = "192.168.130.1/24";
        }
        {
          Address = "fd12:3456:789a::1/64";
        }
      ];
      networkConfig = {
        DHCPServer = true;
        IPv6SendRA = true;
      };
      ipv6Prefixes = [
        {
          Prefix = "fd12:3456:789a::/64";
        }
      ];
    };
    # Bridge all MicroVM tap interfaces to the dedicated bridge
    # This isolates MicroVM traffic from host LAN traffic
    networks."microvm-tap" = {
      matchConfig.Name = "tap-*";
      networkConfig.Bridge = "microvm-br0";
    };
  };


  # Create shared directories for MicroVMs
  systemd.tmpfiles.rules = [
    "d /var/lib/microvm-docker-shared 0755 root root -"
  ];
}
