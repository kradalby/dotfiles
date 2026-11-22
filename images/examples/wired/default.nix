{
  networking.hostName = "edge-01";
  age.secrets.tailscale-preauthkey.file = ./join.age;
}
