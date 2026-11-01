{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  virtualisation.incus.agent.enable = true;

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "ahci"
      "sd_mod"
    ];
  };

  # Raising a guest's incus disk size does nothing on its own: the root partition
  # is last and stays where it is. These two make the guest claim the new
  # space itself at boot, so growing a VM is one number in infrastructure/incus
  # plus a reboot, with no partition surgery on a live root. No-op when the
  # partition already fills the disk.
  boot.growPartition = true;
  # The /tmp tmpfs can mount over growpart's working directory mid-run.
  systemd.services.growpart.environment.TMPDIR = "/run";

  # By label: sdX follows probe order, which a second disk can change.
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };
  };

  swapDevices = [ ];

  # Small VMs (home.ldn runs its whole stack in 1.8 GiB) had no swap at all —
  # one allocation spike away from the OOM killer. zram costs nothing when idle.
  zramSwap.enable = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Common networking setup for Incus VMs
  my.lan = "enp5s0";

  networking = {
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    useDHCP = false;
  };
}
