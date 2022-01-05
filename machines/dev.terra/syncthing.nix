{ config, flakes, pkgs, lib, ... }:
{

  services = {
    syncthing = {
      user = "kradalby";
      dataDir = "/home/kradalby";
      enable = true;
      guiAddress = "0.0.0.0:8443";
      overrideDevices = true;
      overrideFolders = true;
      devices = {
        "kramacbook" = { id = "FN7I426-TXAW62Y-NB623TQ-GW23CIO-MWVQM7Q-TSFNI42-XEIZ4NM-HLX2PAE"; };
        "core.tjoda" = { id = "T77O75Z-XR4MUNF-R6C2AD6-747KQ3X-M4J24YA-YFH3NVC-WDPYMEN-KCH5NAI"; };
        "core.terra" = { id = "CQMXUOP-HPVXOGC-I3GZFS2-XPEK26B-5UCULGA-SGKHNHR-J6FVC2X-UZZQJQV"; };
      };
      folders = {
        "kradalby - Sync" = {
          id = "xTDuT-kZeuK";
          # Name of folder in Syncthing, also the folder ID
          path = "/home/kradalby/Sync"; # Which folder to add to Syncthing
          devices = builtins.attrNames config.services.syncthing.devices; # Which devices to share the folder with
          type = "receiveonly";
        };
      };
    };
  };
}
