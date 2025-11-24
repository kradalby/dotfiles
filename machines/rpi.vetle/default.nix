{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/tailscale.nix

    ../../common/rpi4-configuration.nix
  ];

  my.lan = "eth0";

  networking = {
    hostName = "rpi";
    domain = "vetle.fap.no";
    usePredictableInterfaceNames = lib.mkForce true;
    dhcpcd.enable = true;
    useDHCP = lib.mkDefault true;
  };

  services.tailscale = {
    tags = ["tag:vetle" "tag:server"];
  };

  monitoring.smartctl.devices = ["/dev/sda"];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
