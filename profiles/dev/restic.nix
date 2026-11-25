{ config, ... }:
let
  hostname = builtins.replaceStrings [ ".fap.no" "." ] [ "" "-" ] config.networking.fqdn;
  paths = [
    "/home/kradalby"
    "/root"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-${hostname}-token";
    # A whole live homedir: skip the churn that made every run slow and
    # vanished-file-noisy (exit 3 is also accepted module-wide now).
    extraBackupArgs = [
      "--exclude-caches"
      "--exclude=/home/kradalby/.cache"
      "--exclude=**/.direnv"
      "--exclude=**/node_modules"
    ];
  };
in
{
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
    # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
    # Each host sets targetHost to an opaque repo name, so nothing on the
    # provider side identifies the host.
    jotta = mkJob "jotta" // {
      # Jotta egress is paid/slow: verify metadata only, monthly. The REST
      # repos get the read-data checks.
      check = {
        args = [ ];
        interval = "monthly";
      };
    };
  };
}
