{ lib, config, ... }:
with lib;
{
  services.sslh = {
    enable = true;
    port = 443;
    verbose = true;
    transparent = true;
    appendConfig = ''
      protocols:
      (
        { name: "ssh"; service: "ssh"; host: "localhost"; port: "22"; log_level: 0; tfo_ok: true; keepalive: true; fork: true; },
        { name: "http"; host: "localhost"; port: "80"; log_level: 0; },
        { name: "tls"; host: "localhost"; port: "60443"; log_level: 0; },
        { name: "anyprot"; host: "localhost"; port: "60443"; }
      );
    '';
  };

  # leads to port binding conflicts with nginx sometimes
  systemd.services.sslh.restartIfChanged = true;
}
