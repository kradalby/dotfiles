{pkgs, ...}: {
  home.packages = with pkgs; [
    unstable.speedtest-cli
    age
    ssh-to-age
  ];
}
