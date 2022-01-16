{ lib, ... }: {
  networking.firewall = {
    enable = true;
    allowPing = true;
    pingLimit = "--limit 1/minute --limit-burst 5";
    checkReversePath = lib.mkDefault "strict";
    logRefusedConnections = lib.mkDefault false;

    autoLoadConntrackHelpers = true;
    connectionTrackingModules = [
      "ftp"
      "tftp"
      "netbios_sn"
      "snmp"
    ];
  };
}
