{
  config,
  pkgs,
  lib,
  ...
}: let
  devicesFile = pkgs.writeText "z2m-homekit-devices.hujson" (
    builtins.toJSON {
      devices = [
        # Climate Sensors (Aqara)
        {
          id = "kitchen-aqara";
          name = "Kitchen";
          topic = "kitchen-aqara";
          type = "climate_sensor";
          features = {
            temperature = true;
            humidity = true;
            battery = true;
          };
        }
        {
          id = "bathroom-aqara";
          name = "Bathroom";
          topic = "bathroom-aqara";
          type = "climate_sensor";
          features = {
            temperature = true;
            humidity = true;
            battery = true;
          };
        }
        {
          id = "office-aqara";
          name = "Office";
          topic = "office-aqara";
          type = "climate_sensor";
          features = {
            temperature = true;
            humidity = true;
            battery = true;
          };
        }
        {
          id = "living-room-aqara";
          name = "Living Room";
          topic = "living-room-aqara";
          type = "climate_sensor";
          features = {
            temperature = true;
            humidity = true;
            battery = true;
          };
        }

        # Motion Sensors
        {
          id = "office-motion";
          name = "Office Motion";
          topic = "office-motion";
          type = "occupancy_sensor";
          features = {
            battery = true;
          };
        }

        # Lightbulbs (IKEA Tradfri)
        {
          id = "living-room-speaker-light";
          name = "Living Room Speaker";
          topic = "living-room-speaker-light";
          type = "lightbulb";
          features = {
            brightness = true;
            color = true;
          };
        }
        {
          id = "living-inner-light";
          name = "Living Room Ceiling Inner";
          topic = "living-inner-light";
          type = "lightbulb";
          features = {
            brightness = true;
          };
        }
        {
          id = "living-window-light";
          name = "Living Room Ceiling Window";
          topic = "living-window-light";
          type = "lightbulb";
          features = {
            brightness = true;
          };
        }
      ];
    }
  );
in {
  imports = [
    ../../common/tskey.nix
  ];

  services.z2m-homekit = {
    enable = true;
    package = pkgs.z2m-homekit;

    openFirewall = true;
    dataDir = "/var/lib/z2m-homekit";

    ports = {
      hap = 51831;
      web = 51832;
      mqtt = 51833;
    };

    hap = {
      pin = "03145156";
    };

    devicesConfig = devicesFile;

    tailscale = {
      hostname = "z2m-homekit";
      authKeyFile = config.age.secrets.tailscale-preauthkey.path;
    };

    log.level = lib.mkForce "debug";
  };

  environment.etc."z2m-homekit/devices.hujson" = {
    source = devicesFile;
  };
}
