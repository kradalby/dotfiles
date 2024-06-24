{
  config,
  lib,
  ...
}: {
  imports = [
    ../../common/minio.nix
  ];

  services.minio = {
    dataDir = [
      "/storage/backups/minio"
    ];
  };
}
