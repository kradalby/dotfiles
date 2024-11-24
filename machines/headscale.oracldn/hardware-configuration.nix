{
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  boot.tmp = {
    useTmpfs = lib.mkForce false;
    cleanOnBoot = true;
  };

  boot.initrd.kernelModules = ["nvme"];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/B26E-8D25";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];
  zramSwap.enable = true;
}
