{
  networking.hostName = "cabin-pi";
  services.tailscale.authKeyFile = ./join.key;
  networking.wireless = {
    enable = true;
    networks."Cabin Wi-Fi".psk = "replace-with-your-password";
  };
}
