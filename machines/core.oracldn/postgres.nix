{...}: {
  imports = [../../common/postgres.nix];

  my.postgres.databases = [
    "umami"
    "keycloak"
  ];

  my.postgres.extraBackups = [];

  # Allow the dockerized umami container to connect via trust auth.
  services.postgresql.authentication = ''
    host  umami  umami  172.17.0.1/16   trust
  '';
}
