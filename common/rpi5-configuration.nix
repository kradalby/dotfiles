{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./journal-volatile.nix
  ];

  boot = {
    # rpi5 is mainlined; stock aarch64 kernel works.
    # Keep the NixOS default kernel so zfs-kernel has a matching pair.

    tmp.useTmpfs = true;

    initrd.availableKernelModules = [
      "xhci_pci"
      "uas"
      "usbhid"
      "usb_storage"
      "pcie_brcmstb"
      "reset-raspberrypi"
      "nvme"
    ];

    kernelParams = lib.mkForce [
      "8250.nr_uarts=1"
      "console=ttyAMA10,115200"
      "console=tty1"
      "cma=128M"
    ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = ["nofail" "noauto"];
    };
  };
}
