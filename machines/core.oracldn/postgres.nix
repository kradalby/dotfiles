{...}: {
  imports = [../../common/postgres.nix];

  my.postgres.databases = [
    "glauth"
    "nextcloud"
    "umami"
    "ghostfolio"
    "keycloak"
  ];

  my.postgres.extraBackups = [];
}
