{config, ...}: {
  imports = [
    ./incus.nix
  ];

  # ldn-specific networking configuration
  networking = {
    domain = "ldn.fap.no";
    nameservers = ["10.65.0.1"];
    defaultGateway = {
      address = "10.65.0.1";
      interface = config.my.lan;
    };
  };

  services.tailscale = {
    tags = ["tag:ldn" "tag:server"];
  };

  system.stateVersion = "24.05";
}
