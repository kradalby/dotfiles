{pkgs, ...}: {
  virtualisation.incus.enable = true;
  virtualisation.incus.package = pkgs.incus; # not incus-lts (flagged insecure)
  users.users.kradalby.extraGroups = ["incus-admin"];

  # The Incus bridge is the host's trusted LAN; local services bind here, not wan0.
  my.lan = "incusbr0";

  # Bind the API on all interfaces; the firewall is the gate (wan0 drops it,
  # tailscale0 + incusbr0 are trusted). Set in a oneshot, not the preseed: incus
  # configures the server before creating incusbr0, so binding the bridge IP there
  # fails (cannot assign requested address).
  systemd.services.incus-https-address = {
    description = "Bind the incus API + open metrics (firewall restricts it to tailscale/bridge)";
    after = ["incus-preseed.service"];
    requires = ["incus-preseed.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Same reason the API can't go in the preseed applies here: incus configures
      # the server before incusbr0 exists. metrics_authentication=false exposes the
      # /1.0/metrics endpoint on :8443 without a client cert, scrapeable over the
      # firewalled tailnet/bridge.
      ExecStart = [
        ''${pkgs.incus}/bin/incus config set core.https_address "[::]:8443"''
        ''${pkgs.incus}/bin/incus config set core.metrics_authentication false''
      ];
    };
  };

  virtualisation.incus.preseed = {
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
