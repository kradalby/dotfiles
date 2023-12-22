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

    appendConfig = ''
      upnp_forward_chain=MINIUPNPD
      upnp_nat_chain=MINIUPNPD
      upnp_nat_postrouting_chain=MINIUPNPD-POSTROUTING
    '';

    externalInterface = config.my.wan;
  };
}
