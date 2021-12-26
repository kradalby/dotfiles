{ pkgs, ... }: {
  home.packages = [
    # Workstation
    pkgs.ansible
    pkgs.ansible-lint
    pkgs.drone-cli
    pkgs.exiftool
    pkgs.ipcalc
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.nmap
    pkgs.prettyping
    pkgs.qrencode
    pkgs.terraform
    pkgs.tflint
    pkgs.tfsec
    pkgs.nixopsUnstable

    # pkgs.logcli

    pkgs.python39Packages.pipx
    # osxphotos
  ];
}
