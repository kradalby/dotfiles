{
  config,
  lib,
  ...
}:
{
  imports = [
    ../../common
    ../../common/tailscale.nix
  ];

  networking = {
    hostName = "rpi5";
    domain = "ldn.fap.no";
    useDHCP = lib.mkForce true;
    # Firewall stays ON (was mkForce false with no stated reason): nothing on
    # the Pi serves the LAN; tailnet scrapes ride the tailscale0-scoped opens
    # from the common exporter modules.

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

  services.tailscale.tags = [ "tag:server" ];

  # Headless Pi built under aarch64 emulation. One cut made: enableAllTerminfo
  # pulled a whole GUI stack onto a headless box (contour → qtbase, ghostty →
  # gtk4/wayland/zig, rio, vulkan-loader). The workstation package groups below
  # are DELIBERATELY kept despite the closure size — this Pi doubles as a
  # portable dev/agent box (see flake.nix's rpi5 notes).
  environment.enableAllTerminfo = lib.mkForce false;

  home-manager.users.kradalby.my.packages = {
    userland.enable = true; # neovim (+~284 treesitter grammars), fzf, nh, nix-tree
    go.enable = true;
    nix.enable = true;
    web.enable = true;
    python.enable = true; # uv/ruff/mypy/pyright → numpy/sphinx/websockets/pydantic
    shell.enable = true;
    editor.enable = true;
    infra.enable = true; # ansible/headscale/docker/rnb
    media.enable = false; # ffmpeg/cook-cli/sql-studio/squibble
    ai.enable = true; # claude-code/gemini-cli/opencode/nodejs/python3
  };

  # nixos-raspberrypi is migrating the default from "kernelboot" to
  # "kernel"; opt in explicitly to silence the deprecation warning.
  boot.loader.raspberry-pi.bootloader = "kernel";

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
      options = [ "noatime" ];
    };
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      # Must be mounted (not noauto): the RPi bootloader installer writes kernels
      # + config.txt here on every switch. With noauto it wrote to a shadow dir on
      # the root fs and the real FAT partition never updated, so reboots kept
      # booting the stale generation. nofail keeps the headless box bootable if
      # the partition is ever missing.
      options = [ "nofail" ];
    };
  };

  system.stateVersion = "25.11";
}
