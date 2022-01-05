{
  bridge = {
    name = "Homebridge RPi";
    username = "0E:76:D4:0C:2D:7A";
    port = "51781";
    pin = "031-45-154";
  };
  accessories =
    let
      mqttthingHumiditySensor = name: type: topic:
        (mqttthing name type) //
        {
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
        (mqttthing name type) //
        {
          topics = {
            getCurrentRelativeHumidity = {
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
        (mqttthing name type) //
        {
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

      mqttthingTradfriColour = name: type: topic:
        (mqttthing name type) //
        {
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
          getColorTemprature = {
            topic = "zigbee2mqtt/${topic}";
          };
          setColorTemprature = {
            topic = "zigbee2mqtt/${topic}/set";
          };
        };

      mqttthingAvatarOutlet = name: type: topic:
        (mqttthing name type) //
        {
          onlineValue = "Online";
          manufacturer = "Avatar";
          model = "UK 10A";
          onValue = "ON";
          offValue = "OFF";
          startPub = [
            {
              topic = "cmnd/${topic}/POWER";
              message = "OFF";
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
          };
        };

      mqttthing = name: type: {
        url = "http://localhost:1883";
        username = "homebridge";
        password = "birdbirdbirdistheword";
        accessory = "mqttthing";
        name = name;
        type = type;

        mqttOptions = {
          keepalive = 30;
        };
        whiteMix = true;
      };
    in
    [
      (mqttthingHumiditySensor "Bedroom Humidity" "humiditySensor" "bedroom-aqara")
      (mqttthingTemperatureSensor "Bedroom Temperature" "temperatureSensor" "bedroom-aqara")

      (mqttthingHumiditySensor "Bathroom Humidity" "humiditySensor" "bathroom-aqara")
      (mqttthingTemperatureSensor "Bathroom Temperature" "temperatureSensor" "bathroom-aqara")

      (mqttthingHumiditySensor "Entrance Humidity" "humiditySensor" "entrance-aqara")
      (mqttthingTemperatureSensor "Entrance Temperature" "temperatureSensor" "entrance-aqara")

      (mqttthingHumiditySensor "Living Room Humidity" "humiditySensor" "living-room-aqara")
      (mqttthingTemperatureSensor "Living Room Temperature" "temperatureSensor" "living-room-aqara")

      (mqttthingTradfriColour "Living Room Shelf" "lightbulb" "living-room-shelf-light")
      (mqttthingTradfriColour "Bedroom Speaker" "lightbulb" "bedroom-speaker-light")

      (mqttthingTradfri "Entrance Ceiling" "lightbulb" "entrance-light")
      (mqttthingTradfri "Bedroom Ceiling" "lightbulb" "bedroom-light")

      (mqttthingAvatarOutlet "Bedroom Nook" "outlet" "tasmota_C39499")
      (mqttthingAvatarOutlet "Bedroom Desk" "outlet" "tasmota_C38721")
      (mqttthingAvatarOutlet "Kitchen Fairy Lights" "outlet" "tasmota_5EA590")
      (mqttthingAvatarOutlet "Living Room Fairy Lights" "outlet" "tasmota_6BB357")

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
        accessory = "PhilipsTV";
        name = "Television";
        ip_address = "10.65.0.103";
        poll_status_interval = "30";
        model_year = 2019;
        has_ambilight = true;
        username = "INdLGBCtHWh275OR";
        password = "0cf74acce7c02fee600c8fcd1cea52010a5275fe681a343a6443bab2df272206";
        inputs = [
          { name = "TV Mode"; }
        ];
      }

    ];

  platforms = [
    {
      platform = "config";
      name = "Config";
      port = 8581;
      sudo = false;
    }
  ];
}
