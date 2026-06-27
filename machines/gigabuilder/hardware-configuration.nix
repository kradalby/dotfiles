# PLACEHOLDER — regenerate on the target after install:
#   nixos-generate-config --root /mnt
# then copy the real hardware-configuration.nix over this file. The block below
# matches the planned disk layout (rpool ZFS root + nix, vfat ESP labelled boot,
# dedicated vmpool on nvme1 imported via services.zfs / Incus) so the config
# evaluates as a reference until the real one lands.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid"];
  boot.kernelModules = ["kvm-amd"];

  fileSystems."/" = {
    device = "rpool/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "rpool/nix";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [];

  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  nixpkgs.hostPlatform = "x86_64-linux";
}
