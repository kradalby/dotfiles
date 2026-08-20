{ lib, ... }: {
  imports = [ ../../common/postgres.nix ];

  my.postgres.databases = [
    "umami"
    "keycloak"
  ];

  my.postgres.extraBackups = [ ];

  # Listen only where clients exist: loopback + the docker bridge gateway.
  # enableTCPIP's default was *, exposing postgres to the whole private subnet
  # via the trusted LAN interface.
  services.postgresql.settings.listen_addresses = lib.mkForce "127.0.0.1,172.17.0.1";

  # Allow the dockerized umami container to connect via trust auth. /24, not
  # /16: the default bridge allocates container addresses from 172.17.0.0/24.
  services.postgresql.authentication = ''
    host  umami  umami  172.17.0.0/24   trust
  '';

  # 172.17.0.1 exists only once dockerd creates docker0; a parallel boot
  # start binds loopback-only (postgres logs the failed bind at LOG level and
  # carries on) and umami can't connect until a manual restart.
  systemd.services.postgresql = {
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
  };
}
