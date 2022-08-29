{ pkgs
, lib
  # , flakes
, ...
}:
{
  home.packages = with pkgs; [
    # Workstation
    drone-cli
    exiftool
    ipcalc
    kubectl
    kubernetes-helm
    nmap
    prettyping
    qrencode
    headscale
    step-cli
    colmena
    ragenix

    # nix tooling
    nodePackages.node2nix

    # imapchive

    # Darwin only
    (lib.mkIf pkgs.stdenv.isDarwin terminal-notifier)

    # logcli

    python39Packages.pipx
    # osxphotos
  ];
}
