{ lib, config, modulesPath, ... }:
{
  imports = [
    # Cant be active because it overrides disk device
    # (modulesPath + "/virtualisation/vmware-image.nix")
    (modulesPath + "/virtualisation/vmware-guest.nix")
  ];

  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/sda";
  };


  boot.initrd.availableKernelModules = [ "ata_piix" "mptspi" "uhci_hcd" "ehci_pci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/c4b3bfcd-4bd4-44d7-bd92-d93f939004bd";
      fsType = "ext4";
    };

  swapDevices = [ ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

}

