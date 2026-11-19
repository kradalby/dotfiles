{ lib, ... }:
{
  imports = [ ../../common/postgres.nix ];

  # services.umami creates its own database; this only keeps it in the dump.
  my.postgres.extraBackups = [ "umami" ];

  # Every client is local. enableTCPIP's default is *, exposing postgres to
  # the whole private subnet via the trusted LAN interface.
  services.postgresql.settings.listen_addresses = lib.mkForce "127.0.0.1";
}
