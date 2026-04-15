{inputs, ...}: {
  imports = [inputs.paseo.nixosModules.default];

  services.paseo = {
    enable = true;
    user = "kradalby";
    relay.enable = false;
    hostnames = ["paseo-dev-ldn.dalby.ts.net"];
  };

  services.tailscale.services.paseo-dev-ldn = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:6767";
    };
  };
}
