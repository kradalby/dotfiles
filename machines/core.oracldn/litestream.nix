{
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    ../../common/litestream.nix
  ];

  my.litestream.databases = [
    {
      name = "kuma.db";
      path = "/var/lib/uptime-kuma/kuma.db";
    }
    {
      name = "golink.db";
      path = config.services.golink.databaseFile;
    }
    {
      name = "headscale.sqlite";
      path = "/var/lib/headscale/db.sqlite";
    }
    {
      name = "ghdl.db";
      path = "/var/lib/ghdl/ghdl.db";
    }
  ];

  users = {
    users = {
      litestream = {
        extraGroups = [
          "uptime-kuma"
          config.services.golink.group
          "headscale"
          "ghdl"
        ];
      };
    };
  };

  # litestream (in the headscale group) writes its shadow dir inside the
  # headscale state dir; the module default 0750 denies group write, so
  # headscale replication silently failed. kuma/golink dirs are 0770.
  #
  # setgid (2xxx) so every file — including the -wal/-shm that litestream may
  # create first (it opens the db at boot) — inherits group headscale, not the
  # creator's primary group. Without it, a reboot where litestream wins the race
  # leaves wal/shm as litestream:litestream and headscale can't open its own db
  # (SQLITE_CANTOPEN (14) → crash-loop). UMask 0007 makes the db group-writable
  # (litestream writes _litestream_seq). Same fix as dev.oracfurt/atuin.nix.
  systemd.services.headscale.serviceConfig = {
    StateDirectoryMode = lib.mkForce "2770";
    UMask = lib.mkForce "0007";
  };
  # Correct any db/wal/shm left with the old owner/perms from before this fix,
  # on activation, without recreating the db.
  systemd.tmpfiles.rules = [
    "z /var/lib/headscale/db.sqlite 0660 headscale headscale - -"
    "z /var/lib/headscale/db.sqlite-wal 0660 headscale headscale - -"
    "z /var/lib/headscale/db.sqlite-shm 0660 headscale headscale - -"
  ];
}
