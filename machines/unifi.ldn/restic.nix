{ ... }: let
  paths = [
    "/var/lib/unifi"
  ];

  mkJob = site: {
    inherit site paths;
    secret = "restic-unifi-ldn-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    terra = mkJob "terra";
  };
}
