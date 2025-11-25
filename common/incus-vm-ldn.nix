{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    initrd.availableKernelModules = ["virtio_pci" "virtio_scsi" "ahci" "sd_mod"];
  };

  fileSystems = {
    "/" = {
      device = "/dev/sda2";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/sda1";
      fsType = "vfat";
    };
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Common networking setup for Incus VMs
  my.lan = "enp5s0";

  networking = {
    domain = "ldn.fap.no";
    nameservers = ["10.65.0.1"];
    defaultGateway = {
      address = "10.65.0.1";
      interface = config.my.lan;
    };
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    useDHCP = false;
  };

  services.tailscale = {
    tags = ["tag:ldn" "tag:server"];
  };

  system.stateVersion = "24.05";
}
