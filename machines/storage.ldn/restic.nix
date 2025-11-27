{ config, ... }: let
  paths = [
    "/etc/nixos"
    "/var/lib/libvirt/qemu/win10.xml"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-dev-ldn-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    terra = mkJob "terra";
  };
}
