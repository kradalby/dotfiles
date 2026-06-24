{
  config,
  lib,
  pkgs,
  ...
}: {
  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/disk/by-id/ata-KINGSTON_SA400S37480G_50026B7785A27E08";
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

  fileSystems."/cachestore" = {
    device = "/dev/disk/by-uuid/e7ae0ad1-19fe-4537-b0a3-919e087451a0";
    fsType = "ext4";
    options = ["nofail"];
  };

  # sdd (WDC 2TB) — local mirror of /storage/pictures
  fileSystems."/pictures/album" = {
    device = "/dev/disk/by-uuid/a7a0d495-f21e-4123-9323-25b2fd51da4f";
    fsType = "ext4";
    options = ["nofail"];
  };

  # sda (Crucial 250GB) — generated hugin album, synced from the Mac
  fileSystems."/pictures/hugin" = {
    device = "/dev/disk/by-uuid/7e7f5ab7-bcc6-4207-b401-690a8c22bda4";
    fsType = "ext4";
    options = ["nofail"];
  };

  swapDevices = [{device = "/dev/disk/by-uuid/d471b41a-e5cd-42ef-b818-198bcf636787";}];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
