{ pkgs, ... }: {
  home.packages = with pkgs; [
    unstable.speedtest-cli
    yamllint
    tmuxinator
    shellcheck
    sops
    age
    ssh-to-age
  ];
}
