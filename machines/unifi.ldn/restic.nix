{ ... }: let
  paths = [
    "/var/lib/unifi"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-unifi-ldn-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    terra = mkJob "terra";
  };
}
