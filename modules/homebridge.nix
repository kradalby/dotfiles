{
  config,
  pkgs,
  lib,
  ...
} @ args:
with lib; let
  cfg = config.services.homebridges;

  tradfriCodec = builtins.fetchGit {
    url = "https://github.com/kradalby/tradfri-mqttthing.git";
    ref = "master";
    rev = "c09fe38ce0ae58f1c9216b9dfcb7e05d641eebbe";
  };

  settingsFormat = pkgs.formats.json {};

  baseSettings = {
    name ? "Homebridge NixOS",
    username ? "0E:76:D4:0C:2D:7A",
    port ? 51781,
    uiPort ? 8581,
    pin ? "033-44-254",
  }: {
    bridge = {
      inherit name;
      inherit username;
      inherit port;
      inherit pin;
    };

    platforms = [
      {
        platform = "config";
        name = "Config";
        port = uiPort;
        sudo = false;
      }
    ];
  };
in {
  options.services.homebridges = mkOption {
    default = {};
    type = with types;
      attrsOf (submodule {
        options = {
          enable = mkEnableOption "Enable homebridge";

          package = mkOption {
            type = types.package;
            description = ''
              Package to use
            '';
            default = pkgs.homebridge;
          };

          # dataDir = mkOption {
          #   type = types.path;
          #   default = "/var/lib/homebridges";
          #   description = ''
          #     Directory to store the data
          #   '';
          # };

          devices = mkOption {
            type = types.listOf types.path;
            default = [];
          };

          port = mkOption {
            type = types.port;
            default = 51781;
          };

          uiPort = mkOption {
            type = types.port;
            default = 8000;
          };

          username = mkOption {
            type = types.str;
            default = "0E:76:D4:0C:2D:7A";
          };

          pin = mkOption {
            type = types.str;
            default = "033-44-254";
          };

          settings = mkOption {
            type = types.submodule {
              freeformType = settingsFormat.type;
            };
            default = {};
          };
        };
      });
    description = lib.mdDoc ''
      Multiple Homebridges
    '';
  };

  config = let
    ports = builtins.catAttrs "port" (builtins.attrValues cfg);
  in {
    users.users = flip mapAttrs' cfg (
      n: v: let
        uName = "homebridge-${n}";
        dataDir = "/var/lib/${uName}";
      in
        nameValuePair uName
        {
          home = dataDir;
          createHome = true;
          group = "homebridge";
          extraGroups = ["video"];
          isSystemUser = false;
          isNormalUser = true;
          description = uName;
        }
    );

    users.groups.homebridge = {};

    networking.firewall.allowedTCPPorts = ports;
    networking.firewall.allowedUDPPorts = ports ++ [1900 5350 5351 5353];

    systemd.services = flip mapAttrs' cfg (
      n: v: let
        svcName = "homebridge-${n}";
        configFile = settingsFormat.generate "config.json" (baseSettings {
            name = "Homebridge NixOS ${n}";
            inherit (v) username;
            inherit (v) port;
            inherit (v) uiPort;
            inherit (v) pin;
          }
          // v.settings);
        dataDir = "/var/lib/${svcName}";
      in
        nameValuePair svcName
        {
          inherit (v) enable;
          # confinement = {
          #   enable = true;
          #   mode = "chroot-only";
          # };
          restartTriggers = [v.package];
          script = "exec ${v.package}/bin/homebridge";
          wantedBy = ["multi-user.target"];
          after = ["network.target" "zigbee2mqtt.service" "mosquitto.service"];
          serviceConfig = {
            User = svcName;
            Restart = "always";
            RestartSec = "15";
            # CapabilityBoundingSet = "CAP_NET_RAW";
            AmbientCapabilities = "CAP_NET_RAW";
            DeviceAllow = v.devices;
            WorkingDirectory = dataDir;
          };
          path = [pkgs.ffmpeg];
          environment = {
            HOMEBRIDGE_INSECURE = "1";
            HOMEBRIDGE_CONFIG_UI = "1";
            HOMEBRIDGE_CONFIG_UI_PORT = toString v.uiPort;
          };

          preStart = ''
            ln -sf ${configFile} ${dataDir}/config.json
            ln -sf ${tradfriCodec}/cie-rgb-converter.js ${dataDir}/cie-rgb-converter.js
            ln -sf ${tradfriCodec}/tradfri-codec.js ${dataDir}/tradfri-codec.js
          '';
        }
      # (import ./homebridge/service.nix (args
      #   // {
      #     inherit svcName;
      #     cfg =
      #       v
      #       // {
      #         name =
      #           if v.name != null
      #           then v.name
      #           else n;
      #       };
      #     systemdDir = "homebridge/${n}";
      #   }))
    );
  };
}
