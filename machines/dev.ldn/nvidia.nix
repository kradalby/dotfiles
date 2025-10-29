{
  pkgs,
  lib,
  ...
}: let
  gpuIDs = [
    "10de:1c03" # Graphics
    "10de:10f1" # Audio
  ];
in {
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    pciutils
    virt-manager
    qemu
    OVMF
  ];

  boot.kernelParams = ["intel_iommu=on" ("vfio-pci.ids=" + lib.concatStringsSep "," gpuIDs)];

  boot.blacklistedKernelModules = ["nouveau"];
  # These modules are required for PCI passthrough, and must come before early modesetting stuff
  boot.kernelModules = [
    "vfio"
    "vfio_iommu_type1"
    "vfio_pci"
    "vfio_virqfd"

    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  hardware.graphics.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;

  virtualisation.libvirtd.qemu.verbatimConfig = ''
    nvram = [ "${pkgs.OVMF}/FV/OVMF.fd:${pkgs.OVMF}/FV/OVMF_VARS.fd" ]
  '';

  # CHANGE: add your own user here
  users.groups.libvirtd.members = ["root" "kradalby"];
}
