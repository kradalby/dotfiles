{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    pciutils
    virtmanager
    qemu
    OVMF
  ];

  boot.kernelParams = ["intel_iommu=on"];

  # These modules are required for PCI passthrough, and must come before early modesetting stuff
  boot.kernelModules = ["vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd"];

  # CHANGE: Don't forget to put your own PCI IDs here
  # boot.extraModprobeConfig = "options vfio-pci ids=1002:67b1,1002:aac8";

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;

  virtualisation.libvirtd.qemuVerbatimConfig = ''
    nvram = [ "${pkgs.OVMF}/FV/OVMF.fd:${pkgs.OVMF}/FV/OVMF_VARS.fd" ]
  '';

  # CHANGE: add your own user here
  users.groups.libvirtd.members = ["root" "kradalby"];
}
