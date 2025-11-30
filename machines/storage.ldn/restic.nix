{ config, ... }:
let
  paths = [
    "/etc/nixos"
    "/var/lib/libvirt/qemu/win10.xml"
  ];

  mkJob = site: {
    enable = false;
    inherit site paths;
    secret = "restic-dev-ldn-token";
  };
in
{
  services.restic.jobs.jotta = {
    enable = true;
    repository = "rclone:Jotta:ZW1QYWNrYWdlcyA9IFsKICAgIHBrZ3MuZG";
    secret = "restic-storage-ldn-token";
    inherit paths;
  };
}
