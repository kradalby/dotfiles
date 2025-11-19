{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../common/tskey.nix
  ];

  services.tasmota-homekit = {
    enable = true;
    package = pkgs.tasmota-homekit;

    openFirewall = true;

    ports = {
      hap = 51828;
      web = 51829;
      mqtt = 51830;
    };

    hap = {
      pin = "03145155";
      storagePath = "/var/lib/tasmota-homekit";
    };

    plugsConfig = /etc/tasmota-homekit/plugs.hujson;

    tailscale = {
      hostname = "tasmota-homekit";
      authKeyFile = config.age.secrets.tailscale-preauthkey.path;
    };

    log.level = "debug";
  };

  # Create plugs configuration file
  environment.etc."tasmota-homekit/plugs.hujson" = {
    text = builtins.toJSON {
      plugs = [
        # Living Room plugs
        {
          id = "living-room-corner";
          name = "Living Room Corner";
          address = "living-room-corner.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "living-room-shelf";
          name = "Living Room Shelf Lamp";
          address = "living-room-shelf.ldn";
          model = "Avatar UK 10A";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "living-room-drawer";
          name = "Living Room Drawer";
          address = "living-room-drawer.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "living-room-sofa";
          name = "Living Room Sofa";
          address = "living-room-sofa.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "living-room-tv";
          name = "Living Room TV";
          address = "living-room-tv.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }

        # Office plugs
        {
          id = "office-light";
          name = "Office Ceiling";
          address = "office-light.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "office-air";
          name = "Office Air Purifier";
          address = "office-air.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "office-fan-heater";
          name = "Office Heater";
          address = "office-fan-heater.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "office-fridge";
          name = "Office Fridge";
          address = "office-fridge.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
        {
          id = "office-workstation";
          name = "Office Workstation";
          address = "office-workstation.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }

        # Other plugs
        {
          id = "staircase-servers";
          name = "Staircase Servers";
          address = "staircase-servers.ldn";
          model = "Athom Plug V2";
          features = {
            power_monitoring = true;
            energy_tracking = true;
          };
        }
      ];
    };
  };

}
