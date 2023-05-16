{lib, ...}: {
  networking.firewall = {
    enable = true;
    allowPing = true;
    pingLimit = "--limit 1/minute --limit-burst 5";
    checkReversePath = lib.mkDefault "loose";
    logRefusedConnections = lib.mkDefault false;

    autoLoadConntrackHelpers = false;
    connectionTrackingModules = [
      "ftp"
      "tftp"
      "netbios_sn"
      "snmp"
    ];
  };
}
