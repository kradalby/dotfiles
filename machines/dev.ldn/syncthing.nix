{lib, ...}: {
  imports = [
    ../../common/syncthing-storage.nix
  ];

  services.syncthing.settings.folders = {
    "/fast/hugin" = {
      id = "dd5mf-nwmas";
      path = "/storage/hugin";
      devices = ["kraairm2" "core.terra"];
      type = "receiveonly";
    };
  };
}
