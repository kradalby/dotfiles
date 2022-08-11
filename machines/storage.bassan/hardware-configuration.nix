{ modulesPath, lib, ... }:
{
  # imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  # boot.loader.grub.device = "/dev/vda";
  # boot.initrd.kernelModules = [ "nvme" ];
  # fileSystems."/" = { device = "/dev/vda1"; fsType = "ext4"; };
  # imports = [ ../../common/rpi4-hardware-configuration.nix ];
  #
  # boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;
}
