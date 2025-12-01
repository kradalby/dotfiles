{ config, ... }: let
  paths = [
    "/etc/nixos"
    "/var/lib/kuma"
    "/var/lib/step-ca"
    "/var/lib/mealie"
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
    # terra = mkJob "terra"; # disabled - terra is down
  };
}
