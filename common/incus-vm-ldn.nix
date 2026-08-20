{ config, ... }: {
  imports = [
    ./incus.nix
  ];

  # ldn-specific networking configuration
  networking = {
    domain = "ldn.fap.no";
    # No nameservers override: 10.65.0.1 is plain-53 and refuses DoT, so the
    # forced strict DNSOverTLS made DNS work only via tailscaled. Fall back to
    # the Cloudflare DoT default in common/resolved.nix.
    defaultGateway = {
      address = "10.65.0.1";
      interface = config.my.lan;
    };
  };

  # Baseline for ldn incus VMs; per-machine role tags merge on top. Location
  # tags dropped (nothing keys off them). Authoritative assignment is in
  # infrastructure/tailscale/device_tags.tf — this is only the advertise-on-up.
  services.tailscale = {
    tags = [ "tag:server" ];
  };

  system.stateVersion = "24.05";
}
