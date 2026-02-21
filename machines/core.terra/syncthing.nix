{lib, ...}: {
  imports = [
    ../../common/syncthing-storage.nix
  ];

  services.syncthings.storage.settings.folders = {
    "/fast/hugin" = {
      id = "dd5mf-nwmas";
      path = "/fast/hugin";
      devices = ["krair" "dev.ldn"];
      type = "receiveonly";
    };
  };
}
