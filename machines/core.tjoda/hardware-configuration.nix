{ config, lib, modulesPath, ... }:
{
  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/sda";
  };


  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/6fb6cb76-2e0e-4592-acee-d4e328d7fcd8";
      fsType = "ext4";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/d471b41a-e5cd-42ef-b818-198bcf636787"; }];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
