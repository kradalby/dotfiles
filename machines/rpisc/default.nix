{ inputs, lib, ... }:
let
  pi = inputs.nixos-raspberrypi;
  wifiSource = ../../secrets/rpisc-wifi.age;
  wifiFile = "/run/agenix/rpisc-wifi";
  dhcp = names: metric: {
    matchConfig.Name = names;
    networkConfig.DHCP = "yes";
    dhcpV4Config.RouteMetric = metric;
    ipv6AcceptRAConfig.RouteMetric = metric;
  };
in
{
  imports = [
    pi.nixosModules.raspberry-pi-4.base
    pi.nixosModules.trusted-nix-caches
    ../../common/base.nix
    ../../common/systemd-exporter.nix
    ../../profiles/sd-card.nix
  ];
  _module.args.nixos-raspberrypi = pi;
  nixpkgs.overlays = [
    pi.overlays.bootloader
    pi.overlays.vendor-pkgs
  ];
  # Only the onboard Wi-Fi needs loadable firmware on this headless Pi 4B.
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.wirelessRegulatoryDatabase = true;
  hardware.firmware = [ pi.packages.aarch64-linux.raspberrypiWirelessFirmware ];
  # Provisioning enrolls this node once; normal boots use its persisted identity.
  disabledModules = [ ../../common/tskey.nix ];

  networking = {
    hostName = "rpisc";
    domain = "fap.no";
    wireless = {
      enable = true;
      extraConfig = "p2p_disabled=1";
      extraConfigFiles = [ wifiFile ];
    };
    firewall = {
      allowedUDPPortRanges = lib.mkForce [ ];
      interfaces.tailscale0.allowedTCPPorts = [ 22 ];
    };
  };
  services.openssh.openFirewall = lib.mkForce false;
  systemd.network = {
    networks."20-wired" = dhcp [ "eth*" "en*" ] 100;
    networks."20-wlan" = dhcp [ "wl*" ] 2048;
    wait-online.anyInterface = true;
  };
  # Wired provisioning also works before the site's encrypted profile exists.
  age.secrets = lib.optionalAttrs (builtins.pathExists wifiSource) {
    rpisc-wifi = {
      file = wifiSource;
      owner = "wpa_supplicant";
    };
  };
  systemd.services.wpa_supplicant.unitConfig.ConditionPathExists = wifiFile;

  services.tailscale = {
    enable = true;
    extraSetFlags = [
      "--hostname=rpisc"
      "--ssh"
      "--webclient"
      "--accept-dns=true"
      "--accept-routes=false"
      "--advertise-exit-node=false"
      "--advertise-connector=false"
    ];
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [
      "noatime"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
    ];
  };
  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=16M"
      "mode=0755"
      "nosuid"
      "nodev"
    ];
  };
  # Rotate RAM-backed login logs without updating a state file on the card.
  services.logrotate.extraArgs = [
    "--state"
    "/var/log/logrotate.status"
  ];

  # Keep a clock floor across power loss on the Pi 4, which lacks an RTC.
  services.timesyncd.extraConfig = "SaveIntervalSec=1d";
  documentation.man.enable = false;
  boot.loader.generic-extlinux-compatible.configurationLimit = 3;
  nix.gc.automatic = lib.mkForce false;
  nix.settings = {
    min-free = 512 * 1024 * 1024;
    max-free = 2 * 1024 * 1024 * 1024;
  };
  system.stateVersion = "26.05";
}
