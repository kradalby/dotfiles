{
  networking.hostName = "edge-01";
  services.tailscale.authKeyFile = ./join.key;
}
