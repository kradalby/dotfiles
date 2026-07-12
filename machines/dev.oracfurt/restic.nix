{pkgs, ...}: let
  paths = [
    "/etc/nixos"
    # tsidp runs with DynamicUser; /var/lib/tsidp is a symlink whose target
    # is the real state — backing up the symlink stored ~20 bytes.
    "/var/lib/private/tsidp"
    "/var/lib/cook-server"
    # Consistent daily dump of the atuin sqlite db (below). litestream handles
    # the live/PITR path to garage; this is the offsite snapshot copy — never
    # restic the live db directly (torn snapshot).
    "/var/lib/atuin-backup"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-dev-oracfurt-token";
  };
in {
  # Atomic sqlite copy for restic. sqlite3 .backup is safe against the live db.
  # StateDirectory creates /var/lib/atuin-backup owned by atuin (/var/lib is
  # root-only, so the service can't mkdir it itself).
  systemd.services.atuin-db-dump = {
    serviceConfig = {
      Type = "oneshot";
      User = "atuin";
      Group = "atuin";
      StateDirectory = "atuin-backup";
    };
    path = [pkgs.sqlite];
    script = ''
      sqlite3 /var/lib/atuin/atuin.db ".backup /var/lib/atuin-backup/atuin.db"
    '';
  };
  systemd.timers.atuin-db-dump = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
    # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
    # targetHost is the opaque repo name on Jotta — house convention, nothing
    # host-identifying on the provider side.
    jotta =
      mkJob "jotta"
      // {
        targetHost = "531e044d80bba9c63ec9d1ff2dd12c96";
        # Jotta egress is paid/slow: verify metadata only, monthly. The REST
        # repos get the read-data checks.
        check = {
          args = [];
          interval = "monthly";
        };
      };
  };
}
