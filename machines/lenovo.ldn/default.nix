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

    ./tailscale-headscale.nix

    # ./networking.nix
    ./microvm.nix
    # ./k3s.nix
  ];

  services.tailscale = {
    tags = ["tag:ldn" "tag:server"];
  };

  virtualisation.docker.enable = lib.mkForce false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
