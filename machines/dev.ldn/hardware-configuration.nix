{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_5.override {
  #   argsOverride = rec {
  #     src = pkgs.fetchurl {
  #       url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
  #       sha256 = "sha256-I3Zd1EQlRizZKtvuUmcGCP1/P9GDqDslunp7SIPQRRs=";
  #     };
  #     version = "6.5.1";
  #     modDirVersion = "6.5.1";
  #   };
  # });

  # This is fixed in modern kernels, but the ZFS module is not
  # available for it atm, so we use whatever kernel Nixpkgs has
  # plus this patch.
  boot = {
    kernelPatches = [
      {
        name = "iwlwifi-nuc13"; # descriptive name, required

        patch = ./0001-add-AX1690i-for-NUC-13.patch;
      }
    ];

    # Use the systemd-boot EFI boot loader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "thunderbolt" "usb_storage" "usbhid" "sd_mod"];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # zpool create -f -O canmount=on -O mountpoint=/fast -O compression=zstd -O atime=off -O xattr=sa -O acltype=posixacl fast /dev/nvme1n1 /dev/nvme2n1
    # zfs create -o canmount=off fast/windows
    # zfs create -o canmount=on -o mountpoint=/fast/vm fast/vm
    supportedFilesystems = ["zfs"];
    zfs.extraPools = [
      "fast"
    ];
  };

  powerManagement.powertop.enable = true;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/e89ac6b8-be13-4e22-a4d8-ddc27401a8f0";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/E376-D24E";
      fsType = "vfat";
    };
  };

  swapDevices = [];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp3s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
}
