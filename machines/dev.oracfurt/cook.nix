{...}: let
  port = 9080;
in {
  services.tailscale.services.cook = {
    endpoints = {
      "tcp:80" = "http://localhost:${toString port}";
      "tcp:443" = "http://localhost:${toString port}";
    };
  };

  services.cook-server = {
    enable = true;
    inherit port;
  };
}
