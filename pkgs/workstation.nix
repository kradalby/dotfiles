{ pkgs
, lib
  # , flakes
, ...
}:
{
  home.packages = with pkgs; [
    # Workstation
    ansible
    # ansible-lint
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
    headscale
    unstable.step-cli

    # nix tooling
    nixopsUnstable
    unstable.nodePackages.node2nix

    # Darwin only
    (lib.mkIf pkgs.stdenv.isDarwin terminal-notifier)

    # logcli

    python39Packages.pipx
    # osxphotos
  ] ++ [
    # flakes.agenix.defaultPackage."${pkgs.system}"
  ];
}
