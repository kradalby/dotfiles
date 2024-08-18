{lib, ...}: {
  imports = [
    ../../common/coredns.nix
  ];

  my.coredns.bind = ["lan0" "iot0"];
}
