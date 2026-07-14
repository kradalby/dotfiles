{
  pkgs,
  config,
  ...
}:
let
  port = 56900;
  metricsPort = 56901;
  stateDir = "/var/lib/rclone-jotta";
  rcloneConf = "${stateDir}/rclone.conf";
  rclone = "${pkgs.rclone}/bin/rclone --config ${rcloneConf}";
in
{
  # restic REST proxy fronting Jottacloud: tailnet hosts back up offsite via
  # rest:http://restic-jotta.dalby.ts.net/<scrambled> without holding Jotta
  # credentials. This service owns the ONLY Jotta login on this host — the
  # local jotta job (./restic.nix) also goes through it. Jotta rotates the
  # refresh token on every refresh, so the config must be persistent,
  # writable, and never copied (a diverging copy kills the token family).

  users.users.rclone-jotta = {
    isSystemUser = true;
    group = "rclone-jotta";
  };
  users.groups.rclone-jotta = { };

  systemd.services.rclone-jotta = {
    description = "restic REST proxy for Jottacloud";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      User = "rclone-jotta";
      Group = "rclone-jotta";
      StateDirectory = "rclone-jotta";
      Restart = "on-failure";
      RestartSec = "30";
      # Serves the Jotta root: repos are opaque per-host folders alongside the
      # existing direct-job repos (house convention: scrambled names, nothing
      # host-identifying on the provider side).
      ExecStart =
        "${rclone} serve restic"
        + " --addr 127.0.0.1:${toString port}"
        # Restic packs (~16MiB) exceed the 10MiB default and would buffer via
        # tempdir; Jotta needs the MD5 before upload.
        + " --jottacloud-md5-memory-limit 32Mi"
        # Client prunes must actually free quota; default deletes linger in
        # Jotta trash for 30 days and still count.
        + " --jottacloud-hard-delete"
        + " --metrics-addr :${toString metricsPort}"
        + " Jotta:";
    };
  };

  # Early warning for token-family death (invalid_grant): a failed listing
  # fails the unit and the fleet-wide ServiceFailed alert pages, instead of
  # waiting for every client's jotta backup to go stale.
  systemd.services.rclone-jotta-token-check = {
    description = "Jottacloud token health check";
    serviceConfig = {
      Type = "oneshot";
      User = "rclone-jotta";
      Group = "rclone-jotta";
      ExecStart = "${rclone} lsd Jotta:";
    };
  };
  systemd.timers.rclone-jotta-token-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  services.tailscale.services.restic-jotta = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString port}";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://127.0.0.1:${toString port}";
    };
  };

  # rclone core metrics (no per-repo series — see rclone#7980); scraped as
  # core-tjoda:56901. ACL-approved port: needs the matching grant for
  # tag:monitoring in infrastructure/tailscale/policy.hujson.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ metricsPort ];
}
