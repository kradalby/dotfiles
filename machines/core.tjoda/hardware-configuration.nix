{
  config,
  lib,
  pkgs,
  ...
}: {
  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/disk/by-id/ata-LITEONIT_LCT-256M3S_2.5_7mm_256GB_TW0DFVVG550853AO0052";
    };

    initrd.availableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "usbhid" "uas" "sd_mod"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
    supportedFilesystems = ["zfs"];
    zfs.extraPools = [
      "storage"
    ];
  };

  powerManagement.powertop.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6fb6cb76-2e0e-4592-acee-d4e328d7fcd8";
    fsType = "ext4";
  };

  swapDevices = [{device = "/dev/disk/by-uuid/d471b41a-e5cd-42ef-b818-198bcf636787";}];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
