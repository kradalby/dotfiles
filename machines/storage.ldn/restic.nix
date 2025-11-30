{ config, ... }:
let
  paths = [
    "/etc/nixos"
    "/storage/backup"
    "/storage/libraries"
    "/storage/pictures"
    "/storage/software"
    "/storage/sync"
  ];
in
{
  services.restic.jobs.jotta = {
    enable = true;
    repository = "rclone:Jotta:ZW1QYWNrYWdlcyA9IFsKICAgIHBrZ3MuZG";
    secret = "restic-storage-ldn-token";
    inherit paths;
  };
}
