{ lib, pkgs, ... }:
{
  # The test boots with virtio devices only.
  hardware.firmware = lib.mkForce [ ];
  networking.hostName = "handoff";
  networking.useDHCP = false;
  networking.hosts."192.168.1.1" = [ "control" ];
  systemd.network.networks."10-test-lan" = {
    matchConfig.MACAddress = [
      "52:54:00:12:01:02"
      "52:54:00:12:01:03"
    ];
    address = [ "192.168.1.10/24" ];
  };
  services.tailscale.authKeyFile = "/run/test-join-key";
  services.tailscale.extraUpFlags = [ "--login-server=http://192.168.1.1" ];
  users.users.root.openssh.authorizedKeys.keys = [
    (import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs).snakeOilPublicKey
  ];
}
