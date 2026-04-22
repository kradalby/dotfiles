{
  config,
  lib,
  ...
}: {
  imports = [
    ../../common
    ../../common/tailscale.nix
  ];

  networking = {
    hostName = "rpi5";
    domain = "ldn.fap.no";
    useDHCP = lib.mkForce true;
    firewall.enable = lib.mkForce false;

    wireless = {
      enable = true;
      secretsFile = config.age.secrets.ldn-wifi.path;
      networks = {
        "_kad" = {
          pskRaw = "ext:PSK_UNDERSCORE_KAD";
          priority = 10;
        };
        "_kad24" = {
          pskRaw = "ext:PSK_UNDERSCORE_KAD24";
          priority = 20;
        };
      };
    };
  };

  # networkd default DHCP match only covers eth*/en*.
  systemd.network.networks."40-wlan" = {
    matchConfig.Name = "wl*";
    networkConfig.DHCP = "yes";
    dhcpV4Config.RouteMetric = 2048;
  };

  age.secrets.ldn-wifi.file = ../../secrets/ldn-wifi.age;

  services.tailscale.tags = ["tag:ldn" "tag:server"];

  # Pi5 overclock. Stock is 2.4GHz; 2.8GHz is a conservative bump for
  # a board with the Active Cooler. Raise arm_freq/voltage_delta if
  # you want to push further and are confident in thermals.
  hardware.raspberry-pi.config.pi5.options = {
    arm_freq = {
      enable = true;
      value = 2800;
    };
    over_voltage_delta = {
      enable = true;
      value = 50000;
    };
  };

  # Fan (Active Cooler) PWM thresholds in millidegrees C. Vendor
  # kernel auto-configures the Active Cooler, these just tune the
  # curve — make it a bit more aggressive so temps stay below 70 °C
  # under sustained load.
  hardware.raspberry-pi.config.all.base-dt-params = {
    fan_temp0 = {
      enable = true;
      value = 50000;
    };
    fan_temp0_speed = {
      enable = true;
      value = 75;
    };
    fan_temp1 = {
      enable = true;
      value = 60000;
    };
    fan_temp1_speed = {
      enable = true;
      value = 150;
    };
    fan_temp2 = {
      enable = true;
      value = 67500;
    };
    fan_temp2_speed = {
      enable = true;
      value = 200;
    };
    fan_temp3 = {
      enable = true;
      value = 75000;
    };
    fan_temp3_speed = {
      enable = true;
      value = 255;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = ["nofail" "noauto"];
    };
  };

  system.stateVersion = "25.11";
}
