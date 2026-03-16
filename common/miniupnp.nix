{
  config,
  pkgs,
  lib,
  ...
}: {
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
