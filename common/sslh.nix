{
  lib,
  config,
  ...
}:
with lib; {
  imports = [../modules/sslh.nix];

  config = {
    services.sslh2 = {
      enable = config.my.enableSslh;
      port = 443;
      verbose = true;
      timeout = 5;
      transparent = true;
      appendConfig = ''
        protocols:
        (
          { name: "tls"; host: "localhost"; port: "60443"; log_level: 1; keepalive: true; },
          { name: "ssh"; service: "ssh"; host: "localhost"; port: "22"; log_level: 0; tfo_ok: true; keepalive: true; fork: true; },
          { name: "openvpn"; host: "localhost"; port: "1194"; },
          { name: "anyprot"; host: "localhost"; port: "60443"; }
        );

        on-timeout: "timeout";
      '';
    };

    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.allowedUDPPorts = [443];
  };
}
