{lib, ...}: {
  imports = [
    ../../common/syncthing-storage.nix
  ];

  services.syncthing.settings.folders = {
    "/fast/hugin" = {
      id = "dd5mf-nwmas";
      path = "/fast/hugin";
      devices = ["kraairm2" "dev.ldn"];
      type = "receiveonly";
    };
  };
}
