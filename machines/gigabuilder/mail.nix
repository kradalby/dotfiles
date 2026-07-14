{
  config,
  lib,
  ...
}:
{
  # gigabuilder is the fleet's SMTP relay. The rest of the fleet forwards to
  # smtp.fap.no (which resolves here over the tailnet) with nullmailer;
  # gigabuilder runs the full postfix that accepts those and relays out through
  # Terrahost's spamvask (same provider as gigahost — PTR mx.gigahost.no —
  # relay-by-IP, no auth; the relay core.terra used). :587 is blocked for the
  # hosted IP, so :25.
  #
  # This host runs the real relay, not the send-only spool:
  services.nullmailer.enable = lib.mkForce false;

  services.postfix = {
    enable = true;
    setSendmail = true;
    settings.main = {
      myhostname = "${config.networking.hostName}.${config.networking.domain}";
      myorigin = "${config.networking.hostName}.${config.networking.domain}";
      relayhost = [ "[spamvask.terrahost.no]:25" ];

      # Accept relay only from the tailnet (CGNAT v4 + tailscale ULA v6) + local.
      mynetworks = [
        "127.0.0.0/8"
        "[::1]/128"
        "100.64.0.0/10"
        "[fd7a:115c:a1e0::]/48"
      ];
      inet_interfaces = "all";

      # Opportunistic TLS onward to spamvask.
      smtp_tls_security_level = "may";
    };
    # gigabuilder's own root mail also goes to the personal inbox.
    rootAlias = "kristoffer@dalby.cc";
  };

  # :25 is exposed ONLY on the tailnet interface and, in the ACL, only via
  # tag:smtp — never the public WAN, or gigabuilder becomes an open relay.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 25 ];

  # Postfix queue depth is the signal of stuck outbound mail on the relay.
  services.prometheus.exporters.postfix = {
    enable = true;
    systemd.enable = true;
  };
}
