{
  networking.hostName = "edge-01";
  services.tailscale.authKeyFile = ./join.key;
  networking.useDHCP = false;
  systemd.network.networks."10-uplink" = {
    matchConfig.MACAddress = "02:00:00:00:00:10";
    address = [ "192.0.2.10/24" ];
    routes = [ { Gateway = "192.0.2.1"; } ];
    dns = [ "192.0.2.53" ];
  };
}
