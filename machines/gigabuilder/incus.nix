{pkgs, ...}: {
  virtualisation.incus.enable = true;
  # Full feature release, not incus-lts (the LTS is flagged insecure in nixpkgs).
  virtualisation.incus.package = pkgs.incus;
  users.users.kradalby.extraGroups = ["incus-admin"];

  # The Incus bridge (10.68.0.1) is the host's local/trusted LAN. Exporters and
  # local services bind/open here instead of the public wan0.
  my.lan = "incusbr0";

  # Bind the API on all interfaces; the firewall is the gate — wan0 drops
  # everything except 22/80/443, while tailscale0 + incusbr0 are trustedInterfaces
  # (so the laptop reaches it over tailscale and VMs over the bridge, never wan0).
  # Set it in a oneshot, not the preseed: incus applies server config before it
  # creates incusbr0, so binding a specific bridge IP there fails (bind: cannot
  # assign requested address).
  systemd.services.incus-https-address = {
    description = "Bind the incus API (firewall restricts it to tailscale/bridge)";
    after = ["incus-preseed.service"];
    requires = ["incus-preseed.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = ''${pkgs.incus}/bin/incus config set core.https_address "[::]:8443"'';
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
