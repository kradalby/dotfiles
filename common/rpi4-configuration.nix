{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./journal-volatile.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;

    tmp = {
      useTmpfs = true;
    };

    initrd.availableKernelModules = ["xhci_pci" "uas" "usbhid" "usb_storage"];
    kernelParams = lib.mkForce [
      "8250.nr_uarts=1"

      # Using ttyAMA0 here breaks bluetooth
      # https://github.com/NixOS/nixpkgs/issues/123725#issuecomment-1287563755
      # "console=ttyAMA0,115200"
      "console=ttyS0,115200"

      "console=tty1"
      # Some gui programs need this
      "cma=128M"
    ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  # hardware = {
  #   enableRedistributableFirmware = true;
  #   bluetooth = {
  #     powerOnBoot = true;
  #     enable = true;
  #   };
  # };
  #
  # services.blueman.enable = true;
  #
  # systemd.services.btattach = {
  #   before = ["bluetooth.service"];
  #   after = ["dev-ttyAMA0.device"];
  #   wantedBy = ["multi-user.target"];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.bluez}/bin/btattach -B /dev/ttyAMA0 -P bcm -S 3000000";
  #   };
  # };

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
