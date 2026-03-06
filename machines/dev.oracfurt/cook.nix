{...}: let
  port = 9080;
in {
  services.tailscale.services.cook = {
    endpoints = {
      "http:80" = "http://localhost:${toString port}";
      "https:443" = "http://localhost:${toString port}";
    };
  };

  services.cook-server = {
    enable = true;
    inherit port;
  };
}
