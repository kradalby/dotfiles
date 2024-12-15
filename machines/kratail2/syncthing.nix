{config, ...}: let
  cfg = import ../../metadata/syncthing.nix;
in {
  imports = [../../modules/syncthing.nix];

  services = {
    syncthing = {
      enable = true;
      user = "kradalby";
      dataDir = "/Users/kradalby";
      configDir = "/Users/kradalby/Library/Application Support/Syncthing";
      # guiAddress = "0.0.0.0:8443";
      overrideDevices = true;
      overrideFolders = true;
      inherit (cfg) devices;
      folders = {
        "Sync" = {
          id = "xTDuT-kZeuK";
          path = "/Users/kradalby/Sync";
          devices = builtins.attrNames config.services.syncthing.devices;
          type = "sendreceive";
        };
        "/storage/software" = {
          id = "vpgyn-cj2mg";
          path = "/Volumes/storage/software";
          devices = cfg.storage;
          type = "sendreceive";
        };
        "/storage/books" = {
          id = "ww4gn-xgy9i";
          path = "/Volumes/storage/books";
          devices = cfg.storage;
          type = "sendreceive";
        };
        "/storage/pictures" = {
          id = "orqnv-bg72d";
          path = "/Volumes/storage/pictures";
          devices = cfg.storage;
          type = "sendreceive";
        };
        "/storage/backup" = {
          id = "9bjac-k65uu";
          path = "/Volumes/storage/backup";
          devices = cfg.storage;
          type = "sendreceive";
        };
        "/fast/hugin" = {
          id = "dd5mf-nwmas";
          path = "/Volumes/storage/hugin";
          devices = ["core.terra"];
          type = "sendonly";
        };
      };
    };
  };
}
