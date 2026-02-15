{ config, ... }: let
  paths = [
    "/etc/nixos"
    "/var/lib/kuma"
    "/var/lib/step-ca"
    "/var/lib/mealie"
    "/var/lib/tsidp"
    "/var/lib/cook-server"
    config.services.postgresqlBackup.location
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-dev-oracfurt-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
  };
}
