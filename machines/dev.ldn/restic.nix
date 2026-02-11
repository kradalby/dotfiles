{ config, ... }: let
  paths = [
    "/home/kradalby"
    "/root"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-dev-ldn-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
  };
}
