{ config, ... }: {
  imports = [
    ./incus.nix
  ];

  # ldn-specific networking configuration
  networking = {
    domain = "ldn.fap.no";
    nameservers = [ "10.65.0.1" ];
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
