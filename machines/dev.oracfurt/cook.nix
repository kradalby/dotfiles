{...}: let
  port = 9080;
in {
  # TODO: When Tailscale Services exits beta, use "http:80" and "https:443" instead of "tcp:"
  services.tailscale.services."svc:cook" = {
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
