{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: let
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
          devices = ["core.terra" "core.tjoda"];
          type = "sendonly";
        };
        "/storage/pictures" = {
          id = "orqnv-bg72d";
          path = "/Volumes/storage/pictures";
          devices = ["core.terra" "core.tjoda"];
          type = "sendonly";
        };
        "/storage/backup" = {
          id = "9bjac-k65uu";
          path = "/Volumes/storage/backup";
          devices = ["core.terra" "core.tjoda"];
          type = "sendonly";
        };
        "/fast/album" = {
          id = "qha65-mn9fc";
          path = "/Volumes/storage/hugin/album";
          devices = ["core.terra"];
          type = "sendonly";
        };
      };
    };
  };
}
