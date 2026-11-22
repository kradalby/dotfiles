{ config, ... }:
{
  networking.hostName = "cabin-pi";
  age.secrets.tailscale-preauthkey.file = ./join.age;
  age.secrets.wifi = {
    file = ./wifi.age;
    owner = "wpa_supplicant";
  };
  networking.wireless = {
    enable = true;
    extraConfigFiles = [ config.age.secrets.wifi.path ];
  };
}
