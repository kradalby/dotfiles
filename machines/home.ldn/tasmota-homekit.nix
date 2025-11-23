{
  config,
  pkgs,
  lib,
  ...
}: let
  plugsFile = pkgs.writeText "tasmota-homekit-plugs.hujson" (
    builtins.toJSON {
      plugs = [
        # Living Room plugs
        {
          id = "living-room-corner";
          name = "Living Room Corner";
          address = "10.65.0.82";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          type = "bulb";
        }
        {
          id = "living-room-shelf";
          name = "Living Room Shelf Lamp";
          address = "10.65.0.83";
          model = "Avatar UK 10A";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          type = "bulb";
        }
        {
          id = "living-room-drawer";
          name = "Living Room Drawer";
          address = "10.65.0.84";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          type = "bulb";
        }
        {
          id = "living-room-sofa";
          name = "Living Room Sofa";
          address = "10.65.0.92";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          type = "bulb";
        }
        {
          id = "living-room-tv";
          name = "Living Room TV";
          address = "10.65.0.89";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          homekit = false;
        }

        # Office plugs
        {
          id = "office-light";
          name = "Office Ceiling";
          address = "10.65.0.85";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          type = "bulb";
        }
        {
          id = "office-air";
          name = "Office Air Purifier";
          address = "10.65.0.88";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "office-fan-heater";
          name = "Office Heater";
          address = "10.65.0.93";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "office-fridge";
          name = "Office Fridge";
          address = "10.65.0.90";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          homekit = false;
        }
        {
          id = "office-workstation";
          name = "Office Workstation";
          address = "10.65.0.91";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          homekit = false;
        }

        # Other plugs
        {
          id = "staircase-servers";
          name = "Staircase Servers";
          address = "10.65.0.94";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
          homekit = false;
        }
      ];
    }
  );
in {
  imports = [
    ../../common/tskey.nix
  ];

  services.tasmota-homekit = {
    enable = true;
    package = pkgs.tasmota-homekit;

    openFirewall = true;
    dataDir = "/var/lib/tasmota-homekit";

    ports = {
      hap = 51828;
      web = 51829;
      mqtt = 51830;
    };

    hap = {
      pin = "03145155";
    };

    plugsConfig = plugsFile;

    tailscale = {
      hostname = "tasmota-homekit";
      authKeyFile = config.age.secrets.tailscale-preauthkey.path;
    };

    log.level = lib.mkForce "debug";
  };

  # Create plugs configuration file
  environment.etc."tasmota-homekit/plugs.hujson" = {
    source = plugsFile;
  };

}
