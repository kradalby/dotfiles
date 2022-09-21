{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: let
  network = import ../../common/funcs/network.nix {inherit lib pkgs;};
  s = import ../../metadata/sites.nix {inherit lib config;};
in {
  imports = [
    ../../common
    ./hardware-configuration.nix

    ./k3s.nix
  ];

  my.lan = "ens3";

  networking =
    network.base
    {
      hostName = "k3m1";
      interface = config.my.lan;
      ipv4 = "10.60.0.111";
      site = s.sites.terra;
    };

  # TODO: Remove when terra has consul
  services.consul.extraConfig.retry_join = [];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
