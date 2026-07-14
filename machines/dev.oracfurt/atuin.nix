# Self-hosted atuin shell-history sync server. Reached only over the tailnet
# via the svc:atuin VIP (grant in ~/git/infrastructure); no app-level auth is
# turned off — atuin always needs an account + encryption key, so the tailnet
# grant is the trust boundary and open_registration stays on (tailnet-gated).
#
# SQLite backend (not the module's default postgres) so the DB rides the repo's
# existing litestream tooling, exactly like headscale/golink/kuma.
{
  config,
  lib,
  ...
}:
let
  port = 8888; # atuin default
  metricsPort = 8889; # atuin metrics default
  dbDir = "/var/lib/atuin";
in
{
  services.atuin = {
    enable = true;
    openRegistration = true;
    host = "127.0.0.1";
    inherit port;
    database.createLocally = false; # no postgres
    database.uri = "sqlite://${dbDir}/atuin.db";
  };

  # The module runs atuin as DynamicUser with only an ephemeral RuntimeDirectory
  # and UMask 0077. For a persistent SQLite file that litestream (a separate
  # user) can replicate we need: a stable path, a static user/group litestream
  # can join, a group-writable state dir (shadow dir), and a group-readable db
  # file. Mirrors the headscale override in core.oracldn/litestream.nix, plus a
  # UMask relax because atuin's 0077 (unlike headscale/golink/kuma) hides the db
  # from the group.
  users.users.atuin = {
    isSystemUser = true;
    group = "atuin";
  };
  users.groups.atuin = { };
  systemd.services.atuin.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "atuin";
    Group = "atuin";
    StateDirectory = "atuin";
    # setgid (2xxx) so every file — including the -wal/-shm that litestream may
    # create first — inherits group atuin, not the creator's primary group.
    # Without it litestream's wal/shm land as litestream:litestream and atuin
    # can't open its own db (SQLITE_CANTOPEN); with it both users share group
    # atuin and 0660 lets each read+write the other's files.
    StateDirectoryMode = "2770";
    # litestream (group atuin) writes _litestream_seq into the db, so it needs
    # group WRITE, not just read — 0007 → 0660 db. (0027/read-only made
    # litestream fail with "attempt to write a readonly database".)
    UMask = lib.mkForce "0007";
  };
  # The db + wal/shm created before the mode fixes have the old owner/perms;
  # correct them on activation so litestream and atuin can both open them
  # without recreating the db (and its already-synced history).
  systemd.tmpfiles.rules = [
    "z /var/lib/atuin/atuin.db 0660 atuin atuin - -"
    "z /var/lib/atuin/atuin.db-wal 0660 atuin atuin - -"
    "z /var/lib/atuin/atuin.db-shm 0660 atuin atuin - -"
  ];

  # Native Prometheus metrics. Bind 0.0.0.0 so the monitoring stack on
  # core.oracldn can scrape dev-oracfurt over the tailnet; the module only
  # exposes environmentFile, but systemd .environment merges.
  systemd.services.atuin.environment = {
    ATUIN_METRICS__ENABLE = "true";
    ATUIN_METRICS__HOST = "0.0.0.0";
    ATUIN_METRICS__PORT = toString metricsPort;
  };
  # Metrics reachable on the tailnet only (never WAN); the VIP itself carries
  # the user-facing http traffic.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ metricsPort ];

  # VIP on the home tailnet → atuin.dalby.ts.net.
  services.tailscale.services.atuin.endpoints = {
    "tcp:80" = "http://localhost:${toString port}";
    # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
    "tcp:443" = "http://localhost:${toString port}";
  };
}
