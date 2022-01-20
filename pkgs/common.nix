{ pkgs, ... }: {
  home.packages = with pkgs; [
    unstable.speedtest-cli
    yamllint
    shellcheck
    sops
    age
    ssh-to-age
  ];
}
