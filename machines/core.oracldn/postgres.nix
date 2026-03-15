{...}: {
  imports = [../../common/postgres.nix];

  my.postgres.databases = [
    "umami"
    "keycloak"
  ];

  my.postgres.extraBackups = [];
}
