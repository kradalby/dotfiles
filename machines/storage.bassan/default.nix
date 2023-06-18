{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common

    ./tailscale.nix
    ./wireguard.nix
  ];

  networking = {
    hostName = "storage";
    domain = "bassan.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
    ];
    dhcpcd.enable = true;
    usePredictableInterfaceNames = lib.mkForce true;

    wireless = {
      enable = true;
      networks."abragjest".psk = "interstellar66";
      interfaces = ["wlan0"];
    };
  };

  networking.firewall.allowedUDPPorts = lib.mkForce [
    51280
  ];

  services.consul.extraConfig.retry_join = lib.mkForce [];

  monitoring.smartctl.devices = [];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
