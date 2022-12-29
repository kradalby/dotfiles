{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.miniupnpd;
in {
  disabledModules = ["services/networking/miniupnpd.nix"];

  imports = [
    ../modules/miniupnpd.nix
  ];

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

  # networking.firewall.extraCommands = lib.mkForce ''
  #   ${pkgs.bash}/bin/bash -x ${pkgs.miniupnpd}/etc/miniupnpd/nft_init.sh
  # '';
  # # networking.firewall.extraCommands = lib.mkForce "";
  #
  # networking.firewall.extraStopCommands = lib.mkForce ''
  #   ${pkgs.bash}/bin/bash -x ${pkgs.miniupnpd}/etc/miniupnpd/nft_removeall.sh
  # '';
}
