{
  config,
  lib,
  ...
}: {
  imports = [
    ../../common/minio.nix
  ];

  services = {
    minio = {
      dataDir = [
        "/storage/backup/minio"
      ];
    };

    # Keep tailscale-proxies for headscale network (sfiber)
    tailscale-proxies = {
      minio-sfiber = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.headscale-sfiber-authkey.path;
        loginServer = "https://headscale.sandefjordfiber.no";

        hostname = "minio-tjoda";
        # TODO(kradalby): replace with services.minio.listenAddress
        backendPort = 9000;
      };
    };
  };
}
