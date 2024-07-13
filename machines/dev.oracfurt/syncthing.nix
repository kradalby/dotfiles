{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  cfg = import ../../metadata/syncthing.nix;
  domain = "syncthing.dev.${config.networking.domain}";
in
  lib.mkMerge [
    {
      services = {
        syncthing = {
          user = "kradalby";
          dataDir = "/home/kradalby";
          enable = true;
          overrideDevices = true;
          overrideFolders = true;
          settings = {
            inherit (cfg) devices;
            gui.insecureSkipHostcheck = true;
            folders = {
              "kradalby - Sync" = {
                id = "xTDuT-kZeuK";
                # Name of folder in Syncthing, also the folder ID
                path = "/home/kradalby/Sync"; # Which folder to add to Syncthing
                devices = builtins.attrNames config.services.syncthing.settings.devices; # Which devices to share the folder with
                type = "sendreceive";
              };
            };
          };
        };
      };
    }

    (nginx.internalVhost {
      inherit domain;
      proxyPass = "http://127.0.0.1:8384";
    })
  ]
