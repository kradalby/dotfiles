{lib, ...}: {
  imports = [
    ../../common/syncthing-storage.nix
  ];

  services.syncthing.settings.folders = {
    "/fast/hugin" = {
      id = "dd5mf-nwmas";
      path = "/storage/hugin";
      devices = ["krair" "core.terra"];
      type = "receiveonly";
    };
  };
}
