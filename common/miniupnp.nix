{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.miniupnpd;
in {
  services.miniupnpd = {
    enable = true;
    upnp = true;
    natpmp = true;
    internalIPs = [
      config.my.lan
    ];

    externalInterface = config.my.wan;
  };
}
