{config, ...}: let
  cfg = import ../../metadata/syncthing.nix;
  macosIgnorePatterns = [".DS_Store" "._*" ".Spotlight-V100" ".Trashes" ".fseventsd" ".TemporaryItems"];
in {
  imports = [../../modules/syncthing.nix];

  services = {
    syncthing = {
      enable = true;
      user = "kradalby";
      dataDir = "/Users/kradalby";
      configDir = "/Users/kradalby/Library/Application Support/Syncthing";
      guiAddress = "0.0.0.0:38443";
      overrideDevices = true;
      overrideFolders = true;
      extraOptions = {
        gui.insecureAdminAccess = true;
      };
      inherit (cfg) devices;
      folders = {
        "Sync" = {
          id = "xTDuT-kZeuK";
          path = "/Users/kradalby/Sync";
          devices = builtins.attrNames config.services.syncthing.devices;
          type = "sendreceive";
          ignorePatterns = macosIgnorePatterns;
        };
        "/storage/software" = {
          id = "vpgyn-cj2mg";
          path = "/Volumes/storage/software";
          devices = cfg.storage;
          type = "sendreceive";
          ignorePatterns = macosIgnorePatterns;
        };
        "/storage/books" = {
          id = "ww4gn-xgy9i";
          path = "/Volumes/storage/books";
          devices = cfg.storage;
          type = "sendreceive";
          ignorePatterns = macosIgnorePatterns;
        };
        "/storage/pictures" = {
          id = "orqnv-bg72d";
          path = "/Volumes/storage/pictures";
          devices = cfg.storage;
          type = "sendreceive";
          ignorePatterns = macosIgnorePatterns;
        };
        "/storage/backup" = {
          id = "9bjac-k65uu";
          path = "/Volumes/storage/backup";
          devices = cfg.storage;
          type = "sendreceive";
          ignorePatterns = macosIgnorePatterns;
        };
        "/fast/hugin" = {
          id = "dd5mf-nwmas";
          path = "/Volumes/storage/hugin";
          devices = ["core.terra"];
          type = "sendonly";
          ignorePatterns = macosIgnorePatterns;
        };
      };
    };
  };
}
