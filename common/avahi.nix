{ pkgs, config, ... }:
let
  site = builtins.replaceStrings [ ".fap.no" ] [ "" ] config.networking.domain;
in
{
  services.avahi = {
    enable = true;
    openFirewall = true;

    hostName = "${config.networking.hostName}-${site}";

    nssmdns = true;
    allowPointToPoint = true;

    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };

    extraServiceFiles = {
      ssh = "${pkgs.avahi}/etc/avahi/services/ssh.service";
    };
  };

  systemd.services.avahi-daemon.onFailure = [ "notify-discord@%n.service" ];
}
