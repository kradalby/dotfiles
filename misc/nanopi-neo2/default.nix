{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common/journal-volatile.nix
  ];

  nixpkgs.overlays = [
    (import ./overlay.nix)
  ];

  hardware.enableRedistributableFirmware = true;
  services.getty.autologinUser = "root";
  sdImage.compressImage = false;

  boot = {
    kernelPackages = pkgs.linuxPackagesNanopiNeo2;
    consoleLogLevel = lib.mkDefault 7;
    tmpOnTmpfs = true;
    kernelParams = [
      "cma=32M"
      "console=ttyS2,115200n8"
      "console=ttyACM0,115200n8"
      "console=tty0"
    ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  # hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
}
