{...}: {
  virtualisation.incus.enable = true;
  users.users.kradalby.extraGroups = ["incus-admin"];

  virtualisation.incus.preseed = {
    # API bound to the bridge IP. The laptop reaches it THROUGH the advertised
    # /16 subnet route — never exposed on wan0.
    config."core.https_address" = "10.68.0.1:8443";

    networks = [
      {
        name = "incusbr0";
        type = "bridge";
        config = {
          "ipv4.address" = "10.68.0.1/16"; # host is .1 of the /16
          "ipv4.dhcp.ranges" = "10.68.10.2-10.68.10.254"; # VMs land in 10.68.10.0/24
          "ipv4.nat" = "true"; # internet out wan0
          "ipv4.firewall" = "true"; # Incus owns its nft table
        };
      }
    ];

    profiles = [
      {
        name = "default";
        devices = {
          eth0 = {
            type = "nic";
            network = "incusbr0";
            name = "eth0";
          };
          root = {
            type = "disk";
            pool = "default";
            path = "/";
          };
        };
      }
    ];

    storage_pools = [
      {
        name = "default";
        driver = "zfs";
        config.source = "vmpool"; # dedicated NVMe1 zpool
      }
    ];
  };
}
