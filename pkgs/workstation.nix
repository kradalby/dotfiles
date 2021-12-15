{ pkgs, ... }: {
  home.packages = [
    # Workstation
    pkgs._1password
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

    # pkgs.logcli

    pkgs.python39Packages.pipx
    # osxphotos
  ];
}
