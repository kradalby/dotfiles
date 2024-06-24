{
  config,
  lib,
  ...
}: {
  imports = [
    ../../common/minio.nix
  ];

  age.secrets.headscale-sfiber-authkey = {
    file = ../../secrets/headscale-sfiber-client-preauthkey.age;
    owner = config.users.users.tailscale-proxy.name;
  };

  services = {
    minio = {
      dataDir = [
        "/storage/backup/minio"
      ];
    };
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
