{
  config,
  lib,
  pkgs,
  ...
}: {
  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/disk/by-id/scsi-3600508b1001c721ab38cf39e04d065d6";
  };

  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "hpsa" "usb_storage" "usbhid" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.extraPools = [
    "fast"
    "storage"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3c5dea1a-2662-42c0-abc0-dbfc9a4153e2";
    fsType = "ext4";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/8baa072e-b85b-4611-83e2-5b60fd55a133";}
  ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
