{modulesPath, ...}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  # boot.binfmt.emulatedSystems = [ "amd64-linux" ];

  boot.growPartition = true;
  boot.initrd.kernelModules = ["nvme"];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3D22-F0D6";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/mapper/ocivolume-root";
    fsType = "xfs";
  };

  zramSwap.enable = true;
}
