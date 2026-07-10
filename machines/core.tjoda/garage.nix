{
  config,
  lib,
  ...
}: {
  imports = [
    ../../common/garage.nix
  ];

  services = {
    garage.settings = {
      # Under /storage/backup so the existing restic job to Jottacloud
      # covers it (like MinIO before it).
      metadata_dir = "/storage/backup/garage/meta";
      data_dir = "/storage/backup/garage/data";
    };

    # Keep tailscale-proxies for headscale network (sfiber)
    tailscale-proxies = {
      s3-sfiber = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.headscale-sfiber-authkey.path;
        loginServer = "https://headscale.sandefjordfiber.no";

        hostname = "s3-tjoda";
        backendPort = 3900;
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /storage/backup/garage 0750 garage garage -"
    "d /storage/backup/garage/meta 0750 garage garage -"
    "d /storage/backup/garage/data 0750 garage garage -"
  ];

  # Objects are content-addressed blocks (immutable files, restic-safe), but
  # the metadata DB needs a consistent copy: snapshot it daily next to
  # metadata_dir so the restic run picks it up.
  systemd.services.garage-meta-snapshot = {
    description = "garage metadata snapshot";
    serviceConfig = {
      Type = "oneshot";
      User = "garage";
      Group = "garage";
      EnvironmentFile = config.age.secrets.garage.path;
      ExecStart = "${lib.getExe config.services.garage.package} meta snapshot";
    };
  };
  systemd.timers.garage-meta-snapshot = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
