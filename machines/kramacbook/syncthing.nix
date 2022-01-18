{ config, flakes, pkgs, lib, ... }:
{

  imports = [ ../../modules/syncthing.nix ];

  services = {
    syncthing = {
      enable = true;
      user = "kradalby";
      dataDir = "/Users/kradalby";
      configDir = "/Users/kradalby/Library/Application Support/Syncthing";
      # guiAddress = "0.0.0.0:8443";
      overrideDevices = true;
      overrideFolders = true;
      devices = {
        # "kramacbook" = { id = "FN7I426-TXAW62Y-NB623TQ-GW23CIO-MWVQM7Q-TSFNI42-XEIZ4NM-HLX2PAE"; };
        "core.tjoda" = { id = "T77O75Z-XR4MUNF-R6C2AD6-747KQ3X-M4J24YA-YFH3NVC-WDPYMEN-KCH5NAI"; };
        "core.terra" = { id = "CQMXUOP-HPVXOGC-I3GZFS2-XPEK26B-5UCULGA-SGKHNHR-J6FVC2X-UZZQJQV"; };
        "dev.terra" = { id = "IMAN3KP-YRAZ7OA-OZEXWO2-VALZ6IB-JNLEANA-CHSMUP4-24WNQ33-SXU2MAE"; };
      };
      folders = {
        "Sync" = {
          id = "xTDuT-kZeuK";
          # Name of folder in Syncthing, also the folder ID
          path = "/Users/kradalby/Documents/Sync"; # Which folder to add to Syncthing
          devices = builtins.attrNames config.services.syncthing.devices; # Which devices to share the folder with
          type = "sendreceive";
        };
        "/storage/software" = {
          id = "vpgyn-cj2mg";
          path = "/Volumes/storage/software";
          devices = [ "core.terra" "core.tjoda" ];
          type = "sendonly";
        };
        "/storage/pictures" = {
          id = "orqnv-bg72d";
          path = "/Volumes/storage/pictures";
          devices = [ "core.terra" "core.tjoda" ];
          type = "sendonly";
        };
        "/storage/backup" = {
          id = "9bjac-k65uu";
          path = "/Volumes/storage/backup";
          devices = [ "core.terra" "core.tjoda" ];
          type = "sendonly";
        };
        "/fast/album" = {
          id = "qha65-mn9fc";
          path = "/Volumes/storage/hugin/album";
          devices = [ "core.terra" "core.tjoda" ];
          type = "sendonly";
        };
      };
    };
  };
}
