{ ... }:
let
  port = 9080;
in
{
  services.tailscale.services.cook = {
    endpoints = {
      "tcp:80" = "http://localhost:${toString port}";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://localhost:${toString port}";
    };
  };

  services.cook-server = {
    enable = true;
    inherit port;
  };

  # The VIP proxy keeps the tailnet Host; cook answers 403 to any host it was not told about.
  systemd.services.cook-server.environment.COOK_CORS_ORIGIN = "http://cook.dalby.ts.net,http://cook";
}
