{ pkgs, lib, ... }:
{
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

    (lib.mkIf pkgs.stdenv.isDarwin terminal-notifier)

    # logcli

    python39Packages.pipx
    # osxphotos
  ];
}
