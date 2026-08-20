{ config, ... }:
let
  paths = [
    "/home/kradalby"
    "/root"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-dev-ldn-token";
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
    # targetHost is the opaque repo name on Jotta — house convention, nothing
    # host-identifying on the provider side.
    jotta = mkJob "jotta" // {
      targetHost = "24265df668ee1063b968320aa77677cf";
      # Jotta egress is paid/slow: verify metadata only, monthly. The REST
      # repos get the read-data checks.
      check = {
        args = [ ];
        interval = "monthly";
      };
    };
  };
}
