{...}: {
  imports = [../../common/postgres.nix];

  my.postgres.databases = [
    "glauth"
    "nextcloud"
    "umami"
  ];

  my.postgres.extraBackups = [
    "keycloak"
  ];
}
