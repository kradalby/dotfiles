{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    pciutils
  ];
}
