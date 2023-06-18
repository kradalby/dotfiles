{modulesPath, ...}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  boot.loader.grub.devices = ["/dev/vda"];
  boot.initrd.kernelModules = ["nvme"];
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  zramSwap.enable = true;
}
