{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.tmpOnTmpfs = lib.mkForce false;
  boot.cleanTmpDir = true;
  boot.initrd.kernelModules = [ "nvme" ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  fileSystems."/boot" = { device = "/dev/disk/by-uuid/73A3-5200"; fsType = "vfat"; };
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };


  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];
  zramSwap.enable = true;
}
