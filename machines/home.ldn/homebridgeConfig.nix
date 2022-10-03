{
  bridge = {
    name = "Homebridge RPi";
    username = "0E:76:D4:0C:2D:7A";
    port = 51781;
    pin = "031-45-154";
  };
  accessories = let
    mqttthingHumiditySensor = name: type: topic:
      (mqttthing name type)
      // {
        topics = {
          getCurrentRelativeHumidity = {
            "topic" = "zigbee2mqtt/${topic}";
            "apply" = "return parseFloat(JSON.parse(message).humidity);";
          };
          getStatusLowBattery = {
            "topic" = "zigbee2mqtt/${topic}";
            "apply" = "if (JSON.parse(message).battery < 20) return 1; else return 0;";
          };
        };
      };

    mqttthingTemperatureSensor = name: type: topic:
      (mqttthing name type)
      // {
        topics = {
          getCurrentTemperature = {
            "topic" = "zigbee2mqtt/${topic}";
            "apply" = "return parseFloat(JSON.parse(message).temperature);";
          };
          getStatusLowBattery = {
            "topic" = "zigbee2mqtt/${topic}";
            "apply" = "if (JSON.parse(message).battery < 20) return 1; else return 0;";
          };
        };
      };

    mqttthingTradfri = name: type: topic:
      (mqttthing name type)
      // {
        codec = "tradfri-codec.js";
        topics = {
          getOn = {
            topic = "zigbee2mqtt/${topic}";
          };
          setOn = {
            topic = "zigbee2mqtt/${topic}/set";
          };
          getBrightness = {
            topic = "zigbee2mqtt/${topic}";
          };
          setBrightness = {
            topic = "zigbee2mqtt/${topic}/set";
          };
        };
      };

    mqttthingTradfriTemperature = name: type: topic:
      (mqttthing name type)
      // {
        codec = "tradfri-codec.js";
        topics = {
          getOn = {
            topic = "zigbee2mqtt/${topic}";
          };
          setOn = {
            topic = "zigbee2mqtt/${topic}/set";
          };
          getBrightness = {
            topic = "zigbee2mqtt/${topic}";
          };
          setBrightness = {
            topic = "zigbee2mqtt/${topic}/set";
          };
          getColorTemperature = {
            topic = "zigbee2mqtt/${topic}";
          };
          setColorTemperature = {
            topic = "zigbee2mqtt/${topic}/set";
          };
        };
      };

    mqttthingTradfriColour = name: type: topic:
      (mqttthing name type)
      // {
        codec = "tradfri-codec.js";
        topics = {
          getOn = {
            topic = "zigbee2mqtt/${topic}";
          };
          setOn = {
            topic = "zigbee2mqtt/${topic}/set";
          };
          getBrightness = {
            topic = "zigbee2mqtt/${topic}";
          };
          setBrightness = {
            topic = "zigbee2mqtt/${topic}/set";
          };
          getRGB = {
            topic = "zigbee2mqtt/${topic}";
          };
          setRGB = {
            topic = "zigbee2mqtt/${topic}/set";
          };
        };
      };

    mqttthingTasmotaOutlet = name: type: topic: {
      onlineValue = "Online";
      onValue = "ON";
      offValue = "OFF";
      startPub = [
        {
          topic = "cmnd/${topic}/POWER";
          message = "off";
        }
        {
          topic = "stat/${topic}/POWER";
          message = "";
        }
      ];

      topics = {
        getInUse = "tele/${topic}/STATE";
        getOn = "stat/${topic}/POWER";
        setOn = "cmnd/${topic}/POWER";
        getWatts = {
          topic = "tele/${topic}/SENSOR";
          apply = "return JSON.parse(message).ENERGY.Power;";
        };
        getVolts = {
          topic = "tele/${topic}/SENSOR";
          apply = "return JSON.parse(message).ENERGY.Voltage;";
        };
        getAmperes = {
          topic = "tele/${topic}/SENSOR";
          apply = "return JSON.parse(message).ENERGY.Current;";
        };
        getTotalConsumption = {
          topic = "tele/${topic}/SENSOR";
          apply = "return JSON.parse(message).ENERGY.Total;";
        };
      };
    };

    # https://templates.blakadder.com/avatar_AWP14H.html
    # Tasmota profile:
    # {"NAME":"Avatar UK 10A","GPIO":[0,0,56,0,0,134,0,0,131,17,132,21,0],"FLAG":0,"BASE":45}
    mqttthingAvatarOutlet = name: type: topic:
      (mqttthing name type)
      // {
        manufacturer = "Avatar";
        model = "UK 10A";
      }
      // (mqttthingTasmotaOutlet name type topic);

    mqttthingAthomV2Outlet = name: type: topic:
      (mqttthing name type)
      // {
        manufacturer = "Athom";
        model = "Plug V2";
      }
      // (mqttthingTasmotaOutlet name type topic);

    mqttthingAqaraOccupOutlet = name: topic:
      (mqttthing name "occupancySensor")
      // {
        topics = {
          getOccupancyDetected = {
            topic = "zigbee2mqtt/${topic}";
            apply = "return JSON.parse(message).occupancy;";
          };
          getStatusLowBattery = {
            topic = "zigbee2mqtt/${topic}";
            apply = "if (JSON.parse(message).battery < 20) return 1; else return 0;";
          };
          getBatteryLevel = {
            topic = "zigbee2mqtt/${topic}";
            apply = "return JSON.parse(message).battery;";
          };
        };
      };

    mqttthing = name: type: {
      inherit name;
      inherit type;
      url = "http://localhost:1883";
      username = "homebridge";
      password = "birdbirdbirdistheword";
      accessory = "mqttthing";
      history = true;

      mqttOptions = {
        keepalive = 30;
      };
      # whiteMix = true;
    };
  in [
    (mqttthingHumiditySensor "Kitchen Humidity" "humiditySensor" "kitchen-aqara")
    (mqttthingTemperatureSensor "Kitchen Temperature" "temperatureSensor" "kitchen-aqara")

    (mqttthingHumiditySensor "Bathroom Humidity" "humiditySensor" "bathroom-aqara")
    (mqttthingTemperatureSensor "Bathroom Temperature" "temperatureSensor" "bathroom-aqara")

    (mqttthingHumiditySensor "Office Humidity" "humiditySensor" "office-aqara")
    (mqttthingTemperatureSensor "Office Temperature" "temperatureSensor" "office-aqara")

    (mqttthingHumiditySensor "Living Room Humidity" "humiditySensor" "living-room-aqara")
    (mqttthingTemperatureSensor "Living Room Temperature" "temperatureSensor" "living-room-aqara")

    # (mqttthingTradfriTemperature "Living Room Shelf" "lightbulb" "living-room-shelf-light")

    (mqttthingTradfriColour "Office Speaker" "lightbulb" "office-speaker-light")

    (mqttthingTradfri "Living Room Ceiling Inner" "lightbulb" "living-inner-light")
    (mqttthingTradfri "Living Room Ceiling Window" "lightbulb" "living-window-light")

    # (mqttthingAvatarOutlet "Bedroom Nook" "outlet" "tasmota_C39499")
    # (mqttthingAvatarOutlet "Kitchen Fairy Lights" "outlet" "tasmota_5EA590")
    (mqttthingAvatarOutlet "Living Room Shelf Lamp" "outlet" "tasmota_6BB357")

    (mqttthingAthomV2Outlet "Office Ceiling" "outlet" "tasmota_8F629A")
    (mqttthingAthomV2Outlet "Office Air Purifier" "outlet" "tasmota_97429B")

    (mqttthingAthomV2Outlet "Living Room Corner" "outlet" "tasmota_8F8AC1")
    (mqttthingAthomV2Outlet "Living Room Drawer" "outlet" "tasmota_8F9D84")

    (mqttthingAqaraOccupOutlet "Office motion" "office-motion")

    # Used for measuring power of internet hw
    # (mqttthingAvatarOutlet "Bedroom Desk" "outlet" "tasmota_C38721")

    {
      accessory = "XiaomiRoborockVacuum";
      name = "Martin";
      ip = "10.65.0.80";
      token = "b702812f9ce0620b8f5cdc6344be547b";
      pause = false;
      dock = true;
      waterBox = false;
      cleanword = "cleaning";
    }
    {
      accessory = "NefitEasy";
      name = "Thermostat";
      options = {
        serialNumber = "455010082";
        accessKey = "z4FpZ8hvP6fLX6Hd";
        password = "Atomike1";
      };
    }

    # {
    #   accessory = "PhilipsTV";
    #   name = "Television";
    #   ip_address = "10.65.0.103";
    #   poll_status_interval = "30";
    #   model_year = 2019;
    #   has_ambilight = true;
    #   username = "INdLGBCtHWh275OR";
    #   password = "0cf74acce7c02fee600c8fcd1cea52010a5275fe681a343a6443bab2df272206";
    #   inputs = [
    #     { name = "TV Mode"; }
    #   ];
    # }

    # {
    #   accessory = "PhilipsTV";
    #   name = "Television";
    #   ip_address = "10.65.0.103";
    #   poll_status_interval = "30";
    #   model_year = 2019;
    #   has_ambilight = true;
    #   username = "INdLGBCtHWh275OR";
    #   password = "0cf74acce7c02fee600c8fcd1cea52010a5275fe681a343a6443bab2df272206";
    #   inputs = [
    #     { name = "TV Mode"; }
    #   ];
    # }
  ];

  platforms = [
    {
      platform = "config";
      name = "Config";
      port = 8581;
      sudo = false;
    }

    {
      platform = "Camera-ffmpeg";
      cameras = [
        {
          name = "Entrance";
          manufacturer = "Logitech";
          model = "C270";
          videoConfig = {
            # source = "-f alsa -ac 1 -ar 44100 -thread_queue_size 2048 -i default:CARD=U0x46d0x825,DEV=0 -re -f video4linux2 -i /dev/v4l/by-id/usb-046d_0825_A4221F10-video-index0 -vsync 0 -af aresample=async=1";
            source = "-re -f video4linux2 -i /dev/v4l/by-id/usb-046d_0825_A4221F10-video-index0 -vsync 0 -af aresample=async=1";
            stillImageSource = "-s 1280x720 -f video4linux2 -i /dev/v4l/by-id/usb-046d_0825_A4221F10-video-index0";
            maxStreams = 1;
            maxWidth = 1280;
            maxHeight = 720;
            maxFPS = 30;
            # forceMax = true;
            # maxBitrate = 384;
            # packetSize = 188;
            audio = false;
            debug = false;
            # mapvideo = "1";
            # mapaudio = "0";
          };
        }
      ];
    }
  ];
}
