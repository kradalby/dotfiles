{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Workstation
    ansible
    ansible-lint
    drone-cli
    exiftool
    ipcalc
    kubectl
    kubernetes-helm
    nmap
    prettyping
    qrencode
    terraform
    tflint
    tfsec
    nixopsUnstable

    # logcli

    python39Packages.pipx
    # osxphotos
  ];
}
