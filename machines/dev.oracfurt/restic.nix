{...}: let
  paths = [
    "/etc/nixos"
    # tsidp runs with DynamicUser; /var/lib/tsidp is a symlink whose target
    # is the real state — backing up the symlink stored ~20 bytes.
    "/var/lib/private/tsidp"
    "/var/lib/cook-server"
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
