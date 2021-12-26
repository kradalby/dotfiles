{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.loader.grub.devices = [ "/dev/vda" ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
}

