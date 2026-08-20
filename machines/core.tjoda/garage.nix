{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../common/garage.nix
  ];

  services = {
    garage.settings = {
      # Own dataset, NOT under /storage/backup: that dir is a syncthing
      # sendreceive folder, and a live datadir must not be peer-writable or
      # synced mid-write. Restic covers this path explicitly (restic.nix) and
      # sanoid snapshots the dataset (zfs.nix).
      # Deploy note, one-time, in this order (the unit asserts the mountpoint
      # so a mis-ordered deploy fails loud instead of starting empty):
      #   systemctl stop garage
      #   zfs create -o canmount=on -o mountpoint=/storage/garage storage/garage
      #   mv /storage/backup/garage/meta /storage/backup/garage/data /storage/garage/
      #   chown -R garage:garage /storage/garage
      #   systemctl start garage   (ExecStartPre fixes modes)
      #   rmdir /storage/backup/garage
      metadata_dir = "/storage/garage/meta";
      data_dir = "/storage/garage/data";
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

  # Refuse to start unless the dataset is actually mounted: without this,
  # a mis-ordered deploy (or a failed pool import at boot) would let garage
  # initialize an EMPTY store on the parent filesystem and serve it on the
  # s3-tjoda VIP. Assert (not Condition) so it lands in `failed` and
  # ServiceFailed pages instead of being silently skipped.
  systemd.services.garage.unitConfig.AssertPathIsMountPoint = "/storage/garage";

  # Dir setup as a root ExecStartPre (`+` prefix), not an activation script:
  # run only when the unit actually starts — after the mount assert — so the
  # dirs can never be pre-created on the wrong filesystem. Not tmpfiles: the
  # /storage parent is owned by the storage user, and systemd-tmpfiles refuses
  # the "unsafe path transition" into a garage-owned subtree.
  systemd.services.garage.serviceConfig.ExecStartPre = [
    "+${pkgs.writeShellScript "garage-dirs" ''
      mkdir -p /storage/garage/meta /storage/garage/data
      chown garage:garage /storage/garage /storage/garage/meta /storage/garage/data
      chmod 0750 /storage/garage /storage/garage/meta /storage/garage/data
    ''}"
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
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
