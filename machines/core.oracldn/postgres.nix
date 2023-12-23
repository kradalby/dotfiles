{...}: {
  imports = [../../common/postgres.nix];

  my.postgres.databases = [
    "glauth"
    "nextcloud"
    "umami"
    "ghostfolio"
  ];

  my.postgres.extraBackups = [];
}
