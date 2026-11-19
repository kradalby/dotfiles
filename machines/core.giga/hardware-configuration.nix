# TODO(install): placeholder so the host evaluates before the machine exists.
# Replace with the `nixos-generate-config` output.
{ lib, ... }:
{
  fileSystems."/" = {
    device = "rpool/root";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
