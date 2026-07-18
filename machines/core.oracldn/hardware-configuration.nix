{ modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # boot.binfmt.emulatedSystems = [ "amd64-linux" ];

  # Root is on LVM (/dev/mapper/ocivolume-root → /dev/dm-0); growPartition's
  # parent-disk detection strips trailing digits and yields "/dev/dm-", which
  # doesn't exist → growpart.service fails on every boot. The OCI volume is also
  # already at full size, so there is nothing to grow. Not applicable here.
  boot.growPartition = false;
  boot.initrd.kernelModules = [ "nvme" ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/2060-61BE";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/mapper/ocivolume-root";
    fsType = "xfs";
  };

  zramSwap.enable = true;
}
