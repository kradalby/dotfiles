{ pkgs, ... }: {
  home.packages = [
    pkgs.unstable.speedtest-cli
    pkgs.yamllint
    pkgs.tmuxinator
    pkgs.shellcheck
    pkgs.sops
    pkgs.age
    pkgs.ssh-to-age
  ];
}
