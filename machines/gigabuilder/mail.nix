{
  config,
  lib,
  ...
}: {
  # gigabuilder is the fleet's outbound SMTP relay. Every host sends to
  # smtp.fap.no (which resolves here over the tailnet); gigabuilder relays out
  # through gigahost. gigahost authorises by source IP (gigabuilder is hosted
  # there), so no SMTP AUTH is needed.
  services.postfix.settings.main = {
    # Break the smtp.fap.no -> gigabuilder loop from common/postfix.nix.
    relayhost = lib.mkForce ["[smtp.gigahost.no]:25"];

    # Accept relay from the tailnet (CGNAT v4 + tailscale ULA v6) + localhost.
    mynetworks = [
      "127.0.0.0/8"
      "[::1]/128"
      "100.64.0.0/10"
      "[fd7a:115c:a1e0::]/48"
    ];
    inet_interfaces = "all";

    # Opportunistic TLS to gigahost (encrypt if offered, don't hard-fail).
    smtp_tls_security_level = "may";
  };

  # :25 open ONLY on the tailnet interface — never on the public WAN, or
  # gigabuilder becomes an open relay. mynetworks scopes who may relay; the
  # firewall keeps the port off the internet.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [25];
}
