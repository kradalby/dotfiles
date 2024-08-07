{
  pkgs,
  config,
  ...
}: let
  site = builtins.replaceStrings [".fap.no"] [""] config.networking.domain;
in {
  services.avahi = {
    enable = true;

    hostName = "${config.networking.hostName}-${site}";

    nssmdns4 = true;
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
}
