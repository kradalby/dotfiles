{lib, ...}: {
  imports = [
    ../../common/coredns.nix
  ];

  my.coredns.bind = ["lanbr0" "iot0"];
}
