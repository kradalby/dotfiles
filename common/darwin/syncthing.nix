{ config, lib, ... }:
let
  cfg = import ../../metadata/syncthing.nix;
  # storage.bassan is the untrusted offsite mirror -- it only ever gets this
  # folder encrypted (from core.tjoda/storage.ldn via
  # common/syncthing-storage.nix's mirrorDevice), and darwin has no agenix to
  # hold the passphrase anyway, so keep it out of the plain device list here.
  syncDevices = lib.filter (d: d != "storage.bassan") (
    builtins.attrNames config.services.syncthing.devices
  );
  macosIgnorePatterns = [
    ".DS_Store"
    "._*"
    ".Spotlight-V100"
    ".Trashes"
    ".fseventsd"
    ".TemporaryItems"
  ];
in
{
  imports = [ ../../modules/syncthing-darwin.nix ];

  services = {
    syncthing = {
      enable = true;
      user = "kradalby";
      dataDir = "/Users/kradalby";
      configDir = "/Users/kradalby/Library/Application Support/Syncthing";
      # Loopback only: these are roaming laptops — 0.0.0.0 with
      # insecureAdminAccess exposed an unauthenticated admin UI (folder
      # add/remove = arbitrary file read/write) to any network they joined.
      guiAddress = "127.0.0.1:38443";
      overrideDevices = true;
      overrideFolders = true;
      inherit (cfg) devices;
      folders = {
        "Sync" = {
          id = "xTDuT-kZeuK";
          path = "/Users/kradalby/Sync";
          devices = syncDevices;
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
        "cooklang-recipes" = {
          id = "cooklang-recipes";
          path = "/Users/kradalby/cooklang";
          devices = [ "dev.oracfurt-cooklang" ];
          type = "sendreceive";
          ignorePatterns = macosIgnorePatterns;
        };
      };
    };
  };
}
