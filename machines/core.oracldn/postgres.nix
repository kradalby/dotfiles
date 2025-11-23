{...}: {
  imports = [../../common/postgres.nix];

  my.postgres.databases = [
    "glauth"
    "umami"
    "keycloak"
  ];

  my.postgres.extraBackups = [];
}
